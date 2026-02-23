# frozen_string_literal: true

class CardConditionEvaluator
  TEMPORAL_TYPES = %w[date datetime].freeze

  def initialize(conditions, elements_by_id)
    @conditions = conditions
    @elements_by_id = elements_by_id
  end

  def passes?(card)
    return true if @conditions.nil? || @conditions.empty?

    @conditions.each do |condition|
      field_id = condition["field"]
      query = condition["query"]

      next if field_id.blank? || query.blank?

      element = @elements_by_id[field_id.to_s]
      data_type = element&.data_type
      field_value = card.field_values[field_id.to_s]
      options = condition["options"] || {}

      result = evaluate(query, field_value, data_type, options)
      return false if result == false
    end

    true
  end

  private

  def evaluate(query, field_value, data_type, options)
    case query
    when "IS_EMPTY" then is_empty?(field_value)
    when "IS_NOT_EMPTY" then !is_empty?(field_value)
    when "EQUALS_VALUE" then equals_value?(field_value, options["value"])
    when "DOES_NOT_EQUAL_VALUE" then !equals_value?(field_value, options["value"])
    when "CONTAINS" then contains?(field_value, options["value"])
    when "DOES_NOT_CONTAIN" then !contains?(field_value, options["value"])
    when "IS_EMPTY_OR_EQUALS" then is_empty?(field_value) || equals_value?(field_value, options["value"])
    when "IS_CURRENT_MONTH" then temporal_guard(data_type) { is_current_month?(field_value, data_type) }
    when "IS_NOT_CURRENT_MONTH" then temporal_guard(data_type) { !is_current_month?(field_value, data_type) }
    when "IS_PREVIOUS_MONTH" then temporal_guard(data_type) { is_previous_month?(field_value, data_type) }
    when "IS_FUTURE" then temporal_guard(data_type) { is_future?(field_value, data_type) }
    when "IS_NOT_FUTURE" then temporal_guard(data_type) { !is_future?(field_value, data_type) }
    when "IS_PAST" then temporal_guard(data_type) { is_past?(field_value, data_type) }
    when "IS_NOT_PAST" then temporal_guard(data_type) { !is_past?(field_value, data_type) }
    else
      Rails.logger.error("CardConditionEvaluator: unknown query key '#{query}'")
      true
    end
  end

  def is_empty?(value)
    value.nil? || value == ""
  end

  def equals_value?(field_value, target)
    field_value == target
  end

  def contains?(field_value, search)
    return true if search == ""
    return false if field_value.nil?

    field_value.downcase.include?(search.downcase)
  end

  def temporal_guard(data_type)
    return false unless TEMPORAL_TYPES.include?(data_type)

    yield
  end

  def is_current_month?(field_value, data_type)
    return false if field_value.nil? || field_value == ""

    month_start = current_month_start_string(data_type)
    next_start = next_month_start_string(data_type)

    field_value >= month_start && field_value < next_start
  end

  def is_previous_month?(field_value, data_type)
    return false if field_value.nil? || field_value == ""

    prev_start = previous_month_start_string(data_type)
    curr_start = current_month_start_string(data_type)

    field_value >= prev_start && field_value < curr_start
  end

  def is_future?(field_value, data_type)
    return false if field_value.nil? || field_value == ""
    return false unless valid_temporal_string?(field_value, data_type)

    field_value > now_string(data_type)
  end

  def is_past?(field_value, data_type)
    return false if field_value.nil? || field_value == ""
    return false unless valid_temporal_string?(field_value, data_type)

    field_value < now_string(data_type)
  end

  def valid_temporal_string?(value, data_type)
    if data_type == "datetime"
      value.match?(/\A\d{4}-\d{2}-\d{2}T/)
    else
      value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    end
  end

  def now_string(data_type)
    if data_type == "datetime"
      Time.now.utc.iso8601(3)
    else
      Time.now.utc.strftime("%Y-%m-%d")
    end
  end

  def current_month_start_string(data_type)
    now = Time.now.utc
    date_str = format("%04d-%02d-01", now.year, now.month)
    (data_type == "datetime") ? "#{date_str}T00:00:00.000Z" : date_str
  end

  def next_month_start_string(data_type)
    now = Time.now.utc
    if now.month == 12
      year = now.year + 1
      month = 1
    else
      year = now.year
      month = now.month + 1
    end
    date_str = format("%04d-%02d-01", year, month)
    (data_type == "datetime") ? "#{date_str}T00:00:00.000Z" : date_str
  end

  def previous_month_start_string(data_type)
    now = Time.now.utc
    if now.month == 1
      year = now.year - 1
      month = 12
    else
      year = now.year
      month = now.month - 1
    end
    date_str = format("%04d-%02d-01", year, month)
    (data_type == "datetime") ? "#{date_str}T00:00:00.000Z" : date_str
  end
end
