# frozen_string_literal: true

# Applies a column's card inclusion conditions to a card scope as SQL, so only
# matching cards are loaded. Results match CardConditionEvaluator, which
# filters loaded cards in Ruby; see docs/sql-card-filtering-plan.md.
#
# Everything about a condition itself (skipping blank or unknown conditions,
# checking the field's data type, and computing "now" and month boundaries) is
# decided in Ruby. Only checks on each card's value become SQL, and all values
# are passed as bind parameters.
#
# To match Ruby's comparisons of raw JSON values:
# - Only string values are compared; any other JSON type never matches.
# - Range comparisons use COLLATE "C" to compare bytewise, like Ruby strings.
# - Each predicate is wrapped in COALESCE(..., FALSE) so NOT works like Ruby's !
class CardConditionQuery
  DATE_PATTERN = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
  DATETIME_PATTERN = "^[0-9]{4}-[0-9]{2}-[0-9]{2}T"

  def initialize(conditions, elements_by_id, timezone: "UTC")
    @conditions = conditions
    @elements_by_id = elements_by_id
    @timezone = timezone
  end

  def apply(scope)
    return scope if @conditions.nil? || @conditions.empty?

    @conditions.reduce(scope) do |filtered, condition|
      predicate = predicate_for(condition)
      predicate ? filtered.where(predicate) : filtered
    end
  end

  private

  # Returns a SQL predicate, or nil if the condition doesn't filter anything
  def predicate_for(condition)
    field_id = condition["field"]
    query = condition["query"]

    return nil if field_id.blank? || query.blank?

    key = field_id.to_s
    data_type = @elements_by_id[key]&.data_type
    options = condition["options"] || {}

    case query
    when "IS_EMPTY" then is_empty(key)
    when "IS_NOT_EMPTY" then negate(is_empty(key))
    when "EQUALS_VALUE" then equals_value(key, options["value"])
    when "DOES_NOT_EQUAL_VALUE" then negate(equals_value(key, options["value"]))
    when "CONTAINS" then contains(key, options["value"])
    when "DOES_NOT_CONTAIN" then negate(contains(key, options["value"]))
    when "IS_EMPTY_OR_EQUALS" then either(is_empty(key), equals_value(key, options["value"]))
    when "IS_CURRENT_MONTH" then temporal_guard(data_type) { is_current_month(key, data_type) }
    when "IS_NOT_CURRENT_MONTH" then temporal_guard(data_type) { negate(is_current_month(key, data_type)) }
    when "IS_PREVIOUS_MONTH" then temporal_guard(data_type) { is_previous_month(key, data_type) }
    when "IS_FUTURE" then temporal_guard(data_type) { is_future(key, data_type) }
    when "IS_NOT_FUTURE" then temporal_guard(data_type) { negate(is_future(key, data_type)) }
    when "IS_PAST" then temporal_guard(data_type) { is_past(key, data_type) }
    when "IS_NOT_PAST" then temporal_guard(data_type) { negate(is_past(key, data_type)) }
    else
      Rails.logger.error("CardConditionQuery: unknown query key '#{query}'")
      nil
    end
  end

  # ->> returns NULL for a missing key or JSON null (both nil in Ruby), and ''
  # only for an empty string
  def is_empty(key)
    sql("(cards.field_values ->> :key IS NULL OR cards.field_values ->> :key = '')", key: key)
  end

  def equals_value(key, target)
    case target
    when nil
      # a missing key or JSON null is nil in Ruby, and nil == nil
      sql("cards.field_values ->> :key IS NULL", key: key)
    when String
      sql(<<~SQL, key: key, target: target)
        (jsonb_typeof(cards.field_values -> :key) = 'string' AND cards.field_values ->> :key = :target)
      SQL
    else
      # a non-string option value only equals the same JSON value
      sql("cards.field_values -> :key = CAST(:target AS jsonb)", key: key, target: target.to_json)
    end
  end

  def contains(key, search)
    return "TRUE" if search == ""
    # Ruby raises on a non-string search value unless the field is empty;
    # treat it as not matching instead
    return "FALSE" unless search.is_a?(String)

    # strpos instead of LIKE, so wildcard characters in the search need no escaping
    sql(<<~SQL, key: key, search: search)
      (jsonb_typeof(cards.field_values -> :key) = 'string'
        AND strpos(lower(cards.field_values ->> :key), lower(:search)) > 0)
    SQL
  end

  def is_current_month(key, data_type)
    in_range(
      key,
      CardConditionTime.current_month_start_string(data_type, @timezone),
      CardConditionTime.next_month_start_string(data_type, @timezone)
    )
  end

  def is_previous_month(key, data_type)
    in_range(
      key,
      CardConditionTime.previous_month_start_string(data_type, @timezone),
      CardConditionTime.current_month_start_string(data_type, @timezone)
    )
  end

  def in_range(key, start, finish)
    sql(<<~SQL, key: key, start: start, finish: finish)
      (jsonb_typeof(cards.field_values -> :key) = 'string'
        AND cards.field_values ->> :key <> ''
        AND (cards.field_values ->> :key) COLLATE "C" >= :start
        AND (cards.field_values ->> :key) COLLATE "C" < :finish)
    SQL
  end

  def is_future(key, data_type)
    compare_to_now(key, data_type, ">")
  end

  def is_past(key, data_type)
    compare_to_now(key, data_type, "<")
  end

  def compare_to_now(key, data_type, operator)
    pattern = (data_type == "datetime") ? DATETIME_PATTERN : DATE_PATTERN
    now = CardConditionTime.now_string(data_type, @timezone)
    sql(<<~SQL, key: key, pattern: pattern, now: now)
      (jsonb_typeof(cards.field_values -> :key) = 'string'
        AND cards.field_values ->> :key ~ :pattern
        AND (cards.field_values ->> :key) COLLATE "C" #{operator} :now)
    SQL
  end

  def temporal_guard(data_type)
    return "FALSE" unless CardConditionTime.temporal?(data_type)

    yield
  end

  def negate(predicate)
    "(NOT COALESCE(#{predicate}, FALSE))"
  end

  def either(first, second)
    "(COALESCE(#{first}, FALSE) OR COALESCE(#{second}, FALSE))"
  end

  def sql(fragment, **binds)
    "COALESCE(#{Card.sanitize_sql_array([fragment.squish, binds])}, FALSE)"
  end
end
