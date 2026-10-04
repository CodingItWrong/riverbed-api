# Plan: Move Column Card Filtering from Ruby to SQL

This is the follow-up anticipated under "Performance" in `server-side-filtering-plan.md`: evaluate a column's `card-inclusion-conditions` in a SQL `WHERE` clause instead of loading every card on the board and filtering in Ruby.

The main risk is **changing which cards a column shows**. Most of this plan is about making the SQL version match the Ruby version exactly, proving it does, and being able to switch back instantly.

---

## Why

`GET /columns/:id/cards` (`ColumnsController#cards`) currently does:

```ruby
filtered = column.board.cards.order(:id).select { |card| evaluator.passes?(card) }
```

That loads every card on the board as an ActiveRecord object, deserializes each card's `field_values` jsonb, and filters in Ruby. The cost scales with the board's total card count, not the column's.

Measured in production on board 9 (~9,800 cards, 4 columns), timing each request on its own:

| Request | Cards returned | Time |
|---|---|---|
| `/boards/9/columns` | — | 64ms |
| `/columns/52/cards` | 1 | 380–510ms |
| `/columns/14/cards` | 13 | 361ms |
| `/columns/16/cards` | 54 | 353ms |
| `/columns/15/cards` | 52 | 671ms |
| All four in parallel | — | ~1.2s total |

On the web client these four requests are now about 1.1s of the ~1.7s it takes to load the To Dos board. A 1-card column costs as much as a 50-card one, which points at the full scan, not at serialization.

**Goal:** return the same cards, in the same order, while only matching rows leave Postgres. The target is well under 100ms per column on board 9.

---

## Approach

Add a query object that turns the conditions into SQL predicates, and use it in place of the Ruby `select`:

```ruby
# ColumnsController#cards
filtered = CardConditionQuery
  .new(conditions, elements_by_id, timezone: timezone)
  .apply(column.board.cards)
  .order(:id)
```

`CardConditionQuery#apply(scope)` returns `scope.where(...)`, one predicate per applicable condition, all joined with AND (the same AND logic as now).

### Principles

1. **Compute every time-dependent value in Ruby and pass it as a bind parameter.** "Now", month boundaries and timezone handling stay in Ruby, using the evaluator's existing helpers (moved into a shared module, see below). SQL never calls `now()` or does timezone math. That guarantees the two versions agree, and keeps the existing `Time.now` stubbing in specs working.
2. **Decide everything about the condition itself in Ruby.** Blank `field` or `query` means skip, an unknown query means skip and log, and a non-temporal data type means the condition is false. Only per-card checks become SQL.
3. **Every predicate must return TRUE or FALSE, never NULL.** Wrap each one in `COALESCE(<expr>, FALSE)` before negating, so `NOT` behaves like Ruby's `!` on missing values.
4. **Only text values take part in comparisons.** Guard with `jsonb_typeof(field_values -> :field) = 'string'`. See "Non-string values" below.
5. **Compare bytewise, like Ruby.** Use `COLLATE "C"` on every `<`, `>`, `<=` and `>=` between strings. Equality is already bytewise for deterministic collations.
6. **Only bind parameters.** Field IDs, search values and boundaries all go through `sanitize_sql_array` or Arel. No string interpolation.

### Building blocks

For a condition on field `f`:

- `v` = `field_values -> :f` (jsonb, or NULL if the key is missing)
- `t` = `field_values ->> :f` (text; NULL if the key is missing or the value is JSON `null`)
- `is_str` = `jsonb_typeof(field_values -> :f) = 'string'`

In Ruby, `card.field_values[f]` is `nil` both when the key is missing and when it holds JSON `null`, and `t IS NULL` covers exactly those two cases.

---

## Semantics: Ruby → SQL

Each row has to reproduce `CardConditionEvaluator` exactly, including the edge cases its spec covers (see the Testing section).

| Query | Ruby (current) | SQL predicate |
|---|---|---|
| `IS_EMPTY` | `v.nil? \|\| v == ""` | `t IS NULL OR (is_str AND t = '')` |
| `IS_NOT_EMPTY` | negation | `NOT COALESCE(<IS_EMPTY>, FALSE)` |
| `EQUALS_VALUE` | `v == target` | target is a String: `is_str AND t = :target`. Target is `nil` (option missing): `t IS NULL` |
| `DOES_NOT_EQUAL_VALUE` | negation | `NOT COALESCE(<EQUALS_VALUE>, FALSE)` |
| `CONTAINS` | `""` search is always true; `nil` value is false; otherwise `v.downcase.include?(search.downcase)` | `:search = ''` → `TRUE`; otherwise `is_str AND strpos(lower(t), lower(:search)) > 0` |
| `DOES_NOT_CONTAIN` | negation | `NOT COALESCE(<CONTAINS>, FALSE)` |
| `IS_EMPTY_OR_EQUALS` | empty or equals | `COALESCE(<IS_EMPTY>, FALSE) OR COALESCE(<EQUALS_VALUE>, FALSE)` |
| `IS_CURRENT_MONTH` | non-temporal type is false; empty is false; otherwise `start <= v < next_start` (string compare) | type check in Ruby → `FALSE`; otherwise `is_str AND t <> '' AND t COLLATE "C" >= :start AND t COLLATE "C" < :next_start` |
| `IS_NOT_CURRENT_MONTH` | non-temporal type is false; otherwise negation | type check in Ruby → `FALSE`; otherwise `NOT COALESCE(<IS_CURRENT_MONTH>, FALSE)` |
| `IS_PREVIOUS_MONTH` | like current month, previous range | same shape with `:prev_start` and `:curr_start` |
| `IS_FUTURE` | empty is false; invalid format is false; otherwise `v > now` | `is_str AND t ~ :format AND t COLLATE "C" > :now` |
| `IS_NOT_FUTURE` | non-temporal type is false; otherwise negation | type check in Ruby → `FALSE`; otherwise `NOT COALESCE(<IS_FUTURE>, FALSE)` |
| `IS_PAST` / `IS_NOT_PAST` | mirror of future | `<` instead of `>` |
| unknown query | logged, treated as passing | skipped; log the same message |

Notes:

- **`CONTAINS` uses `strpos`, not `ILIKE`.** That avoids escaping `%`, `_` and `\` in user-entered search text. Escaping is the most likely source of a subtle mismatch, so it's better not to need it.
- **Format regexes:** date is `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`, datetime is `^[0-9]{4}-[0-9]{2}-[0-9]{2}T`. Use `[0-9]` rather than `\d`, because Ruby's `\d` is ASCII-only and Postgres's `\d` can depend on the locale.
- **Same Ruby strings for `now` and the boundaries:** `now_string(data_type)` and the month-boundary strings are exactly what the evaluator produces today: `iso8601(3)` UTC for datetime, `%Y-%m-%d` in the request's timezone for date.
- **Temporal type check:** missing element means `data_type` is `nil`, so the condition becomes literal `FALSE`, matching `temporal_guard`.

### Non-string values (needs a data audit first)

Ruby compares the raw JSON value, while SQL's `->>` turns everything into text. The two only diverge for values that aren't strings:

- **Geolocation fields** store an object (`{"lat": "…", "lng": "…"}`).
  - Ruby: `IS_EMPTY` is false and `EQUALS_VALUE` is false. `CONTAINS` raises `NoMethodError` (`Hash#downcase`), and the date conditions raise too (`Hash` has no `>=` to compare with a `String`). Either way the request returns a 500.
  - SQL with the `is_str` guard: the same falses for empty and equals. `CONTAINS` and the date conditions return false instead of raising.
- **Numbers and booleans:** the web client stores numbers as strings, but other clients (iOS) or old data might not. Ruby's `5 == "5"` is false, while SQL's `'5' = '5'` would be true without the guard. The `is_str` guard keeps Ruby's behavior.

The only intended behavior change is that those 500s become "no match". Call it out in the PR.

Before implementing, check production (read-only):

```sql
-- what JSON types are stored, per element data type
SELECT e.data_type, jsonb_typeof(kv.value) AS json_type, count(*)
FROM cards c
CROSS JOIN LATERAL jsonb_each(c.field_values) kv
JOIN elements e ON e.id::text = kv.key
GROUP BY 1, 2 ORDER BY 1, 2;

-- which queries and option types are actually in use
SELECT cond->>'query' AS query, jsonb_typeof(cond->'options'->'value') AS value_type, count(*)
FROM columns, jsonb_array_elements(card_inclusion_conditions) cond
GROUP BY 1, 2 ORDER BY 1, 2;

SHOW lc_collate;
```

If anything unexpected turns up, such as numbers in a text field or non-string option values, add parity test cases for it before writing the SQL.

---

## Code changes

| File | Change |
|---|---|
| `app/services/card_condition_time.rb` (new) | Move `now_string`, `current_month_start_string`, `next_month_start_string`, `previous_month_start_string` and the format patterns out of the evaluator. Both implementations use it, so their boundaries can't drift apart. |
| `app/services/card_condition_evaluator.rb` | Use `CardConditionTime`. No behavior change. It stays only during rollout, as the reference for the parity specs and as the fallback; it's deleted in the cleanup step. |
| `app/services/card_condition_query.rb` (new) | `initialize(conditions, elements_by_id, timezone:)` and `apply(scope)`, building one predicate per condition as described above. |
| `app/controllers/columns_controller.rb` | `#cards` uses `CardConditionQuery` behind a switch (see Rollout). |

Leave the `#cards` serialization as it is. A possible follow-up is `pluck(:id, :field_values)` to skip ActiveRecord object creation for the matching rows, but once filtering happens in SQL there are few rows left, so it's unlikely to matter.

### Indexes

Not needed at first. The query is still `WHERE board_id = ?` (indexed) plus jsonb predicates evaluated in Postgres. At ~10k rows that should be tens of milliseconds, and the benchmark below will confirm it. Expression indexes on specific fields wouldn't generalize, because each column filters on different fields.

---

## Testing

### 1. Parity spec: run the existing evaluator spec against both implementations

`spec/unit/card_condition_evaluator_spec.rb` (711 lines) already lists every query and its edge cases: nil vs `""`, whitespace, case sensitivity, empty search, invalid dates, month boundaries, timezones and non-temporal types. Reuse all of it:

- Extract its cases into a shared example group, parameterized by an `evaluate(conditions, field_values, elements_by_id, timezone)` helper.
- **Ruby implementation:** the current `instance_double` cards.
- **SQL implementation:** create a real `Card` with those `field_values` on a board, then check `CardConditionQuery.new(...).apply(Card.where(id: card.id)).exists?`.
- Both run every existing case, so any disagreement is a failing test. `freeze_to` keeps working because "now" is computed in Ruby.

Add cases for whatever the data audit finds (object, number and boolean values), plus `CONTAINS` search text containing `%`, `_` and `\`, and non-ASCII text.

### 2. Randomized cross-check

A spec that builds, say, 500 cards with random field values (strings, empty strings, nulls, missing keys, dates, datetimes, garbage strings, objects) and random condition sets, then asserts that both implementations return the same set of card IDs. This catches combinations the hand-written cases miss. Use a fixed seed so failures can be reproduced.

### 3. Request spec

`spec/requests/column_cards_spec.rb` should pass unchanged, including the UTC vs Kolkata timezone cases and the "never returns cards from other boards" case.

### 4. Benchmark

Seed a local board with ~10k cards shaped like board 9, plus a column with 2–3 conditions. Time `GET /columns/:id/cards` before and after. Expect hundreds of milliseconds before and tens after. Record the numbers in the PR.

---

## Rollout

1. **Switch:** `ENV["CARD_FILTERING"]` set to `"ruby"` (default) or `"sql"`, read in `#cards`. Switching back is just an env change, with no deploy.
2. **Shadow mode (temporary):** a third value, `"compare"`, runs both, returns the Ruby result, and logs a warning when the ID sets differ. Log the column ID, the conditions and the differing card IDs, but no field values, since they're user content. This doubles the cost while it's on, so enable it for a day or two of normal use, check the logs, then turn it off.
3. **Switch to `"sql"`**, then re-measure board 9's column requests in production.
4. **Clean up: retire the Ruby implementation.** After a quiet period on `"sql"`:
   - Convert the parity spec to fixed expected results. Each case asserts whether the SQL query includes the card, using the result the Ruby evaluator produced, so no case is lost.
   - Delete `CardConditionEvaluator`, the switch and the compare mode.
   - Keep the randomized check's seeds and convert its useful cases into fixed examples, since it can no longer compare against Ruby.

   This leaves one implementation. Keeping both long-term would mean every new or changed condition type has to be written twice and kept in sync, and the parity spec only catches drift for cases someone wrote a test for.

---

## Risks and how this plan addresses them

| Risk | Mitigation |
|---|---|
| SQL and Ruby disagree on an edge case, so cards appear or disappear | The parity spec runs every existing case on both; randomized cross-check; shadow mode in production; instant switch back |
| String comparison differs because of the database collation | `COLLATE "C"` on all range comparisons; equality is already bytewise |
| Case-insensitive `CONTAINS` differs for non-ASCII text (Postgres `lower()` follows the database locale, Ruby `downcase` is full Unicode) | Parity cases with accented and other non-ASCII letters; check `lc_collate`. If they differ, accept it for ASCII-only or document the difference. |
| Wildcards in search text | `strpos` instead of `LIKE`, so there's nothing to escape |
| Time boundaries drift between the implementations | Shared `CardConditionTime` module; boundaries are computed in Ruby and bound as parameters |
| Two implementations drift apart over time | The Ruby evaluator is deleted after rollout, with its spec cases kept as fixed expectations for the SQL version |
| New field types store values that aren't text (arrays, JSON numbers) | Their filters would silently not match rather than error. Any new field type needs deliberate SQL handling and test cases. |
| SQL injection through field IDs or values | Bind parameters only; field IDs are also checked against `elements_by_id` or a pattern |
| Non-string values (geolocation objects, possibly numbers) | `is_str` guard reproduces Ruby; data audit first; the 500s from `CONTAINS` and date conditions on objects become "no match", called out in the PR |

---

## Out of scope

- Changing condition semantics, such as making `EQUALS_VALUE` case-insensitive or treating whitespace-only values as empty. The goal is identical results.
- A single endpoint that returns all of a board's columns' cards in one request. That would also cut the client's four requests to one, but it's a separate change and is easier to do after this one.
- Client changes. The response is unchanged.
