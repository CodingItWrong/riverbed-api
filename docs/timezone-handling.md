# Time Zone Handling for Server-Side Filtering

## Problem

Several column filter conditions evaluate card field values relative to the server's concept of "now": the current date, current month, previous month, and whether a value is in the past or future. The server currently computes "now" using `Time.now.utc`, which ties all temporal comparisons to UTC.

Clients can be located anywhere in the world. If a user in UTC−8 opens their app at 11 pm on March 14, the server's UTC clock already reads March 15. A filter for "current month" or "is future" will behave differently from what the user expects because the server and the client disagree on what day it is.

---

## Affected Filter Conditions

The following query operators are time-zone-sensitive for **both `date` and `datetime`** fields.

### `date` fields

`date` fields store only a calendar date (`YYYY-MM-DD`) with no time component. "Today" and "current month" are inherently local concepts, so all temporal filters depend on the client's timezone.

| Query | Why timezone matters |
|---|---|
| `IS_CURRENT_MONTH` | Current month is determined by today's local date |
| `IS_NOT_CURRENT_MONTH` | Inverse of `IS_CURRENT_MONTH` |
| `IS_PREVIOUS_MONTH` | Previous month is determined by today's local date |
| `IS_FUTURE` | "Future" means after today's local date |
| `IS_NOT_FUTURE` | Inverse of `IS_FUTURE` |
| `IS_PAST` | "Past" means before today's local date |
| `IS_NOT_PAST` | Inverse of `IS_PAST` |

### `datetime` fields

`datetime` fields store values as UTC ISO 8601 strings (`2024-03-15T14:30:00.000Z`).

**Month-boundary filters are affected by timezone.** Consider a client in UTC+5:30 when UTC is 2024-03-31 23:00. The client's local time is 2024-04-01 04:30 — already in April. A `datetime` value of `"2024-04-01T00:00:00.000Z"` is past the UTC month boundary but is within the client's current month (April in Kolkata). Using UTC boundaries would incorrectly exclude it.

| Query | Effect of timezone |
|---|---|
| `IS_CURRENT_MONTH` | Month boundaries computed from the client's local month start, converted to UTC for comparison |
| `IS_NOT_CURRENT_MONTH` | Inverse of `IS_CURRENT_MONTH` |
| `IS_PREVIOUS_MONTH` | Previous month boundaries computed from the client's local timezone |

**Point-in-time filters are timezone-invariant.** Whether a UTC moment is in the past or future is the same regardless of what timezone the client is in.

| Query | Effect of timezone |
|---|---|
| `IS_FUTURE` | No effect — compares UTC instant against UTC now |
| `IS_NOT_FUTURE` | No effect |
| `IS_PAST` | No effect — compares UTC instant against UTC now |
| `IS_NOT_PAST` | No effect |

**Summary:** timezone affects all temporal queries on `date` fields, and affects month-boundary queries (`IS_CURRENT_MONTH`, `IS_NOT_CURRENT_MONTH`, `IS_PREVIOUS_MONTH`) on `datetime` fields.

---

## Proposed Solution

### Overview

The client passes its local IANA timezone name as a query parameter when calling `GET /columns/:id/cards`. The server uses that timezone to compute the local date when evaluating temporal filters on `date` fields. If the parameter is omitted, UTC is used as a safe default.

### Why a query parameter?

Alternatives considered:

| Option | Pros | Cons |
|---|---|---|
| Query parameter on `GET /columns/:id/cards` | Simple, stateless, no schema change | Client must send on every request |
| `Accept-Timezone` HTTP header | Follows header conventions | Non-standard; requires middleware |
| Stored per-user in the database | Single source of truth | Adds schema migration; requires user to set; stale if user travels |
| Stored per-board or per-column | Granular control | Overkill; additional schema changes |

A query parameter is the simplest approach: it is stateless (no migration needed), easy to add to a single endpoint, and puts the timezone decision at the point of the request where the client knows its current locale. The server does not need to remember timezone state, which avoids stale-data problems.

### Parameter specification

| Parameter | Type | Required | Default | Example |
|---|---|---|---|---|
| `timezone` | IANA timezone name string | No | `"UTC"` | `America/New_York` |

If the client sends an unrecognized timezone name, the server returns **422 Unprocessable Entity** with a JSON:API error body so the client can handle it gracefully.

**Example request:**

```
GET /columns/42/cards?timezone=America%2FNew_York
```

**Example error response (invalid timezone):**

```json
{
  "errors": [
    {
      "code": "422",
      "title": "Invalid timezone",
      "detail": "timezone - is not a valid IANA timezone"
    }
  ]
}
```

---

## Implementation Plan

### Files to modify

| File | Change |
|---|---|
| `app/controllers/columns_controller.rb` | Read and validate `params[:timezone]`; pass to `CardConditionEvaluator` |
| `app/services/card_condition_evaluator.rb` | Accept `timezone` keyword argument; use client's local date for `date` field comparisons |

### Files to create/update (tests)

| File | Change |
|---|---|
| `spec/unit/card_condition_evaluator_spec.rb` | Add tests verifying timezone-aware behavior for `date` fields |
| `spec/requests/column_cards_spec.rb` | Add integration tests for the `timezone` query parameter |

---

### `CardConditionEvaluator` changes

Add an optional `timezone` keyword argument (defaulting to `"UTC"`) to `initialize`:

```ruby
def initialize(conditions, elements_by_id, timezone: "UTC")
  @conditions = conditions
  @elements_by_id = elements_by_id
  @timezone = timezone
end
```

Update the private helper methods to use the client's timezone:

```ruby
def now_string(data_type)
  if data_type == "datetime"
    Time.now.utc.iso8601(3)   # IS_FUTURE/IS_PAST: moment comparison, timezone-invariant
  else
    Time.now.in_time_zone(@timezone).strftime("%Y-%m-%d")
  end
end

def current_month_start_string(data_type)
  now = Time.now.in_time_zone(@timezone)
  if data_type == "datetime"
    # Compute UTC equivalent of local month start for datetime range comparison
    ActiveSupport::TimeZone[@timezone].local(now.year, now.month, 1).utc.iso8601(3)
  else
    format("%04d-%02d-01", now.year, now.month)
  end
end
```

`next_month_start_string` and `previous_month_start_string` follow the same pattern.

All month-boundary methods use the client's local timezone for both `date` and `datetime` fields. For `datetime` fields, the local month start is converted to its UTC equivalent so it can be compared against UTC-stored datetime values.

`IS_FUTURE`/`IS_PAST` on `datetime` fields remain UTC-based since those are moment-in-time comparisons.

### `ColumnsController#cards` changes

```ruby
def cards
  column = current_user.columns.find_by(id: params[:id])
  return render_not_found unless column

  timezone = params[:timezone].presence || "UTC"
  unless valid_timezone?(timezone)
    render json: {errors: [{code: "422", title: "Invalid timezone",
                            detail: "timezone - is not a valid IANA timezone"}]},
           status: :unprocessable_entity, content_type: jsonapi_content_type
    return
  end

  elements_by_id = column.board.elements.index_by { |e| e.id.to_s }
  conditions = column.card_inclusion_conditions
  evaluator = CardConditionEvaluator.new(conditions, elements_by_id, timezone: timezone)

  filtered = column.board.cards.order(:id).select { |card| evaluator.passes?(card) }

  render json: {data: filtered.map { |card| serialize_card(card) }},
    content_type: jsonapi_content_type
end

private

def valid_timezone?(tz_name)
  ActiveSupport::TimeZone.find_tzinfo(tz_name)
  true
rescue TZInfo::InvalidTimezoneIdentifier
  false
end
```

---

## Backward Compatibility

- The `timezone` parameter is **optional**. Existing clients that do not send it will continue to receive UTC-based results, which is the current behavior.
- No database migrations are required.
- No changes to other endpoints.

---

## Notes

### Why IANA names instead of Rails zone names?

IANA timezone identifiers (e.g., `America/New_York`, `Europe/London`) are the industry standard used by iOS, Android, and most modern clients. Rails' `ActiveSupport::TimeZone` supports IANA names via the underlying `tzinfo` gem, so `Time.now.in_time_zone("America/New_York")` works without any mapping.

### `IS_FUTURE` / `IS_PAST` on `datetime` fields remain UTC-based

`datetime` field values are stored as UTC ISO 8601 strings. `IS_FUTURE` and `IS_PAST` compare those UTC strings against the current UTC moment — the result is the same regardless of what timezone the client is in (a moment in time either has passed or has not, independent of timezone). Month-boundary filters (`IS_CURRENT_MONTH`, `IS_PREVIOUS_MONTH`) do depend on timezone because "current month" is a calendar concept that varies by locale.
