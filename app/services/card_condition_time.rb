# frozen_string_literal: true

# Time values used by temporal card conditions, shared by CardConditionEvaluator
# and CardConditionQuery so both compare against exactly the same strings.
#
# Field values are stored as strings, so all comparisons are string comparisons:
# dates as "YYYY-MM-DD" in the request's timezone, and datetimes as ISO 8601
# UTC strings with milliseconds.
module CardConditionTime
  TEMPORAL_TYPES = %w[date datetime].freeze

  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  DATETIME_FORMAT = /\A\d{4}-\d{2}-\d{2}T/

  module_function

  def temporal?(data_type)
    TEMPORAL_TYPES.include?(data_type)
  end

  def valid_temporal_string?(value, data_type)
    value.match?((data_type == "datetime") ? DATETIME_FORMAT : DATE_FORMAT)
  end

  def now_string(data_type, timezone)
    if data_type == "datetime"
      Time.now.utc.iso8601(3)
    else
      Time.now.in_time_zone(timezone).strftime("%Y-%m-%d")
    end
  end

  def current_month_start_string(data_type, timezone)
    month_start_string(Time.now.in_time_zone(timezone), data_type)
  end

  def next_month_start_string(data_type, timezone)
    month_start_string(Time.now.in_time_zone(timezone).next_month, data_type)
  end

  def previous_month_start_string(data_type, timezone)
    month_start_string(Time.now.in_time_zone(timezone).prev_month, data_type)
  end

  def month_start_string(time, data_type)
    if data_type == "datetime"
      time.beginning_of_month.utc.iso8601(3)
    else
      format("%04d-%02d-01", time.year, time.month)
    end
  end
end
