# Server-Side Card Filtering Plan

This document describes the plan for implementing `GET /columns/:id/cards`, which returns only the cards that satisfy a column's `card-inclusion-conditions`.

---

## Overview

The endpoint evaluates each card on the column's board against the column's conditions (AND logic). Cards that pass all conditions are returned in JSON:API format. The filtering logic is extracted into a service object (`CardConditionEvaluator`) so it can be tested independently and reused.

---

## Files to Create

| File | Purpose |
|---|---|
| `app/services/card_condition_evaluator.rb` | Service object encapsulating all query logic |
| `spec/requests/column_cards_spec.rb` | Integration tests for the HTTP endpoint |
| `spec/unit/card_condition_evaluator_spec.rb` | Unit tests for every query type and edge case |

## Files to Modify

| File | Change |
|---|---|
| `config/routes.rb` | Add `get :cards, on: :member` to the `columns` resource |
| `app/controllers/columns_controller.rb` | Add `cards` action; add private `serialize_card` helper |

---

## Route Change

```ruby
resources :columns, only: %w[show create update destroy] do
  get :cards, on: :member
end
```

This yields `GET /columns/:id/cards` without changing any existing routes.

---

## Service Object: `CardConditionEvaluator`

**Location:** `app/services/card_condition_evaluator.rb`

### Interface

```ruby
evaluator = CardConditionEvaluator.new(conditions, elements_by_id)
evaluator.passes?(card)  # => true / false
```

- `conditions` — the column's `card_inclusion_conditions` array (may be nil or empty)
- `elements_by_id` — hash of `field_id (string) => Element` (for data type lookup)
- `card` — a `Card` instance; field values read from `card.field_values`

### Algorithm

Directly mirrors the spec's pseudocode:

1. If conditions is nil or empty → `true`
2. For each condition:
   - If `field` or `query` key is missing/blank → skip (treat as passing)
   - Look up element by `condition["field"]` to get `data_type`
   - Read `field_value` from `card.field_values[field_id]`
   - Evaluate the named query function
   - If the query returns false → card fails, short-circuit
3. If all conditions pass → `true`

Unknown query keys log an error and are treated as passing (skipped).

### Temporal String Helpers

Per the spec, temporal comparisons are done **lexicographically on strings**:

- **"now" for `date`**: `Time.now.utc.strftime("%Y-%m-%d")`
- **"now" for `datetime`**: `Time.now.utc.iso8601(3)` → `"2024-03-15T14:30:00.123Z"`
- **Month start**: `"YYYY-MM-01"` constructed without parsing
- **Next/previous month start**: computed by incrementing/decrementing month and wrapping year

This avoids timezone-sensitive Date/DateTime parsing and relies entirely on the sortable string properties guaranteed by the spec.

### Query Implementations

#### `IS_EMPTY`
```
field_value.nil? || field_value == ""
```

#### `IS_NOT_EMPTY`
```
!IS_EMPTY(field_value)
```

#### `EQUALS_VALUE`
```
field_value == options["value"]
```
Strict equality (`==`), case-sensitive.

#### `DOES_NOT_EQUAL_VALUE`
```
!EQUALS_VALUE(field_value, options["value"])
```

#### `CONTAINS`
```
if options["value"] == "" then true
elsif field_value.nil? then false
else field_value.downcase.include?(options["value"].downcase)
```

#### `DOES_NOT_CONTAIN`
```
!CONTAINS(field_value, options["value"])
```

#### `IS_EMPTY_OR_EQUALS`
```
IS_EMPTY(field_value) || EQUALS_VALUE(field_value, options["value"])
```

#### Temporal queries (IS_CURRENT_MONTH, IS_PREVIOUS_MONTH, IS_FUTURE, IS_PAST and their inverses)

All temporal queries **guard first on data type**:
```
return false unless data_type in ["date", "datetime"]
```

For the `IS_NOT_*` variants, this same guard applies — non-temporal types return `false`, not `true`. Then for temporal types, `IS_NOT_*` is the strict mathematical inverse of its positive counterpart.

| Query | Temporal logic |
|---|---|
| `IS_CURRENT_MONTH` | `value >= month_start && value < next_month_start` |
| `IS_NOT_CURRENT_MONTH` | `!(IS_CURRENT_MONTH)` |
| `IS_PREVIOUS_MONTH` | `value >= prev_month_start && value < current_month_start` |
| `IS_FUTURE` | `value > now_string` (strict) |
| `IS_NOT_FUTURE` | `!(IS_FUTURE)` |
| `IS_PAST` | `value < now_string` (strict) |
| `IS_NOT_PAST` | `!(IS_PAST)` |

For all temporal queries: nil or blank value returns `false`.

Month boundary strings are built like:
- Current month start: `"2024-03-01"` (append `T00:00:00.000Z` for datetime comparisons)
- For datetime values, the date-only boundary string `"2024-03-01"` still works because
  `"2024-03-01T..." > "2024-03-01"` (longer string is lexicographically greater when prefix matches)

---

## Controller Action

```ruby
def cards
  column = current_user.columns.find_by(id: params[:id])
  return render_not_found unless column

  elements_by_id = column.board.elements.index_by { |e| e.id.to_s }
  conditions = column.card_inclusion_conditions
  evaluator = CardConditionEvaluator.new(conditions, elements_by_id)

  filtered = column.board.cards.order(:id).select { |card| evaluator.passes?(card) }

  render json: { data: filtered.map { |card| serialize_card(card) } },
         content_type: jsonapi_content_type
end
```

A private `serialize_card` helper (same format as `CardsController#serialize_card`) will be added to `ColumnsController`.

---

## Test Plan

### Integration Tests: `spec/requests/column_cards_spec.rb`

#### Authentication
- `GET /columns/:id/cards` when logged out → 401, empty body

#### Authorization / not found
- Column belonging to another user → 404 with JSON:API error structure
- Non-existent column ID → 404

#### No conditions (all cards pass)
- Column with `nil` `card_inclusion_conditions` → returns all board cards *(tested at unit level only — the `card_inclusion_conditions` DB column has a NOT NULL constraint, so nil cannot be set via `update!` in an integration test)*
- Column with `[]` `card_inclusion_conditions` → returns all board cards

#### Filtering in action
- Column with `IS_NOT_EMPTY` condition: board has one card with the field filled, one without
  - Only the filled card is returned
- Column with two conditions (AND): card must satisfy both to be included
  - Cards satisfying only condition 1 → excluded
  - Cards satisfying only condition 2 → excluded
  - Cards satisfying both → included
  - Cards satisfying neither → excluded

#### Response format
- Returns status 200
- `Content-Type: application/vnd.api+json`
- Top-level `data` key is an array
- Each element has `type: "cards"`, `id` (string), `attributes: {"field-values" => {...}}`

#### Cross-board isolation
- Cards on other boards (same user) are never returned

---

### Unit Tests: `spec/unit/card_condition_evaluator_spec.rb`

The unit spec tests `CardConditionEvaluator` directly, injecting controlled conditions, elements, and cards. Time-sensitive tests use `allow(Time).to receive(:now)` (or `Timecop`) to freeze "now".

The spec is organized as one `describe` block per query key. Each block tests:
- At least one **true** case
- At least one **false** case
- **Boundary** conditions (empty string, nil, exact boundary values)
- **Invalid / missing** values specific to that query
- For temporal queries: **non-temporal data types** (must return false)

---

#### Top-level evaluator behavior

| Scenario | Expected |
|---|---|
| `conditions` is `nil` | `true` for any card |
| `conditions` is `[]` | `true` for any card |
| Condition missing `field` key | condition skipped, card passes |
| Condition missing `query` key | condition skipped, card passes |
| Condition has blank `field` | condition skipped |
| Unknown `query` key | condition skipped (logged), card passes |
| All conditions pass | `true` |
| First condition fails | `false` (short-circuits) |
| Last condition fails | `false` |
| Multiple conditions, all pass | `true` |

---

#### `IS_EMPTY`

| field_value | Expected |
|---|---|
| `nil` | `true` |
| `""` | `true` |
| `"hello"` | `false` |
| `"0"` | `false` |
| `" "` (whitespace) | `false` (non-empty string) |

#### `IS_NOT_EMPTY`

| field_value | Expected |
|---|---|
| `nil` | `false` |
| `""` | `false` |
| `"hello"` | `true` |
| `"0"` | `true` |

---

#### `EQUALS_VALUE`

| field_value | options.value | Expected |
|---|---|---|
| `"approved"` | `"approved"` | `true` |
| `"Approved"` | `"approved"` | `false` (case-sensitive) |
| `"approved"` | `"Approved"` | `false` |
| `""` | `"approved"` | `false` |
| `nil` | `"approved"` | `false` |
| `""` | `""` | `true` (empty equals empty) |
| `"a"` | `""` | `false` |

#### `DOES_NOT_EQUAL_VALUE`

| field_value | options.value | Expected |
|---|---|---|
| `"approved"` | `"approved"` | `false` |
| `"Approved"` | `"approved"` | `true` |
| `""` | `"approved"` | `true` |
| `nil` | `"approved"` | `true` |
| `""` | `""` | `false` |

---

#### `CONTAINS`

| field_value | options.value | Expected |
|---|---|---|
| `"capybara"` | `"yba"` | `true` |
| `"Capybara"` | `"YBA"` | `true` (case-insensitive) |
| `"capybara"` | `"YBA"` | `true` |
| `"cat"` | `"yba"` | `false` |
| `nil` | `"yba"` | `false` |
| `""` | `"yba"` | `false` |
| `"anything"` | `""` | `true` (empty value always true) |
| `nil` | `""` | `true` (empty value always true) |
| `""` | `""` | `true` |

#### `DOES_NOT_CONTAIN`

| field_value | options.value | Expected |
|---|---|---|
| `"capybara"` | `"yba"` | `false` |
| `"Capybara"` | `"YBA"` | `false` |
| `"cat"` | `"yba"` | `true` |
| `nil` | `"yba"` | `true` |
| `"anything"` | `""` | `false` (inverse of CONTAINS=true) |
| `nil` | `""` | `false` |

---

#### `IS_EMPTY_OR_EQUALS`

| field_value | options.value | Expected |
|---|---|---|
| `""` | `"a"` | `true` (empty) |
| `nil` | `"a"` | `true` (empty) |
| `"a"` | `"a"` | `true` (equals) |
| `"b"` | `"a"` | `false` |
| `"A"` | `"a"` | `false` (case-sensitive equals) |
| `"a"` | `""` | `false` (non-empty, doesn't equal "") |
| `""` | `""` | `true` (empty satisfies IS_EMPTY) |

---

#### `IS_CURRENT_MONTH` (date type, frozen to 2024-03-15)

| field_value | Expected |
|---|---|
| `"2024-03-01"` (first of month) | `true` |
| `"2024-03-15"` (mid month) | `true` |
| `"2024-03-31"` (last of month) | `true` |
| `"2024-02-28"` (previous month) | `false` |
| `"2024-04-01"` (next month) | `false` |
| `"2023-03-15"` (same month, last year) | `false` |
| `nil` | `false` |
| `""` | `false` |
| `"not-a-date"` | `false` |

#### `IS_CURRENT_MONTH` (datetime type, frozen to 2024-03-15T12:00:00.000Z)

| field_value | Expected |
|---|---|
| `"2024-03-01T00:00:00.000Z"` | `true` |
| `"2024-03-15T12:00:00.000Z"` | `true` |
| `"2024-03-31T23:59:59.999Z"` | `true` |
| `"2024-02-28T23:59:59.999Z"` | `false` |
| `"2024-04-01T00:00:00.000Z"` | `false` |
| `nil` | `false` |

#### `IS_CURRENT_MONTH` (non-temporal types)

| data_type | field_value | Expected |
|---|---|---|
| `text` | `"2024-03-15"` | `false` |
| `number` | `"2024-03-15"` | `false` |
| `choice` | `"2024-03-15"` | `false` |
| `geolocation` | any | `false` |

#### `IS_NOT_CURRENT_MONTH` (date type, frozen to 2024-03-15)

| field_value | Expected |
|---|---|
| `"2024-03-15"` (current month) | `false` |
| `"2024-02-28"` (previous month) | `true` |
| `"2024-04-01"` (next month) | `true` |
| `nil` | `true` (inverse: IS_CURRENT_MONTH(nil) = false) |
| `""` | `true` |

#### `IS_NOT_CURRENT_MONTH` (non-temporal types)

| data_type | Expected |
|---|---|
| `text` | `false` |
| `number` | `false` |

---

#### `IS_PREVIOUS_MONTH` (date type, frozen to 2024-03-15)

| field_value | Expected |
|---|---|
| `"2024-02-01"` (first of previous month) | `true` |
| `"2024-02-15"` (mid previous month) | `true` |
| `"2024-02-29"` (last of previous month, leap year) | `true` |
| `"2024-03-01"` (current month start) | `false` (boundary) |
| `"2024-01-31"` (two months ago) | `false` |
| `"2024-03-15"` (current month) | `false` |
| `nil` | `false` |
| `""` | `false` |

**Year boundary** (frozen to 2024-01-15):

| field_value | Expected |
|---|---|
| `"2023-12-31"` | `true` (previous month crosses year) |
| `"2024-01-01"` | `false` |
| `"2023-11-30"` | `false` |

#### `IS_PREVIOUS_MONTH` (non-temporal types)

| data_type | Expected |
|---|---|
| `text` | `false` |

---

#### `IS_FUTURE` (date type, frozen to 2024-03-15)

| field_value | Expected |
|---|---|
| `"2024-03-16"` (tomorrow) | `true` |
| `"2024-03-15"` (today — boundary) | `false` (today is NOT future) |
| `"2024-03-14"` (yesterday) | `false` |
| `"2025-01-01"` (far future) | `true` |
| `nil` | `false` |
| `""` | `false` |
| `"not-a-date"` | `false` (invalid string, lexicographically < any date) |

#### `IS_FUTURE` (datetime type, frozen to 2024-03-15T12:00:00.000Z)

| field_value | Expected |
|---|---|
| `"2024-03-15T12:00:00.001Z"` (1ms ahead) | `true` |
| `"2024-03-15T12:00:00.000Z"` (exact now — boundary) | `false` (not strictly future) |
| `"2024-03-15T11:59:59.999Z"` (1ms before) | `false` |
| `nil` | `false` |

#### `IS_FUTURE` (non-temporal types)

| data_type | Expected |
|---|---|
| `text` | `false` |
| `number` | `false` |
| `choice` | `false` |

#### `IS_NOT_FUTURE` (date type, frozen to 2024-03-15)

| field_value | Expected |
|---|---|
| `"2024-03-16"` | `false` |
| `"2024-03-15"` (today — boundary) | `true` (today is not future, so IS_NOT_FUTURE = true) |
| `"2024-03-14"` | `true` |
| `nil` | `true` (inverse: IS_FUTURE(nil) = false) |

#### `IS_NOT_FUTURE` (non-temporal types)

| data_type | Expected |
|---|---|
| `text` | `false` |

---

#### `IS_PAST` (date type, frozen to 2024-03-15)

| field_value | Expected |
|---|---|
| `"2024-03-14"` (yesterday) | `true` |
| `"2024-03-15"` (today — boundary) | `false` (today is NOT past) |
| `"2024-03-16"` (tomorrow) | `false` |
| `"2020-01-01"` (far past) | `true` |
| `nil` | `false` |
| `""` | `false` |

#### `IS_PAST` (datetime type, frozen to 2024-03-15T12:00:00.000Z)

| field_value | Expected |
|---|---|
| `"2024-03-15T11:59:59.999Z"` (1ms before) | `true` |
| `"2024-03-15T12:00:00.000Z"` (exact now — boundary) | `false` |
| `"2024-03-15T12:00:00.001Z"` (1ms ahead) | `false` |
| `nil` | `false` |

#### `IS_PAST` (non-temporal types)

| data_type | Expected |
|---|---|
| `text` | `false` |
| `number` | `false` |
| `choice` | `false` |

#### `IS_NOT_PAST` (date type, frozen to 2024-03-15)

| field_value | Expected |
|---|---|
| `"2024-03-14"` | `false` |
| `"2024-03-15"` (today — boundary) | `true` (today is not past) |
| `"2024-03-16"` | `true` |
| `nil` | `true` (inverse: IS_PAST(nil) = false) |

#### `IS_NOT_PAST` (non-temporal types)

| data_type | Expected |
|---|---|
| `text` | `false` |

---

## Notes

### Loading elements
The controller loads all elements for the board (not just field-type elements) and indexes by `id.to_s`. Conditions referencing button element IDs (or IDs not present in the board) will result in a nil element, meaning `data_type` is nil. All temporal queries guard on `data_type` and will return false for nil. All other queries operate on the field_value without needing data_type.

### Performance
The current approach loads all cards into memory and filters in Ruby. For boards with large card counts, a future optimization could push temporal conditions into a SQL `WHERE` clause. This is acceptable for a first implementation.

### `field_values` key format
Field IDs are stored as integer column values in the database but as string keys in `field_values` JSONB. The condition's `field` attribute is also a string (element ID). The evaluator must consistently use string keys when looking up both elements and field values.

### Time zone
All "now" calculations use `Time.now.utc` to ensure consistency with the ISO 8601 UTC values stored in `datetime` fields and the UTC-anchored date boundaries described in the spec.
