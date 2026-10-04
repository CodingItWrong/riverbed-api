# frozen_string_literal: true

require "rails_helper"

# Cross-checks CardConditionQuery (SQL) against CardConditionEvaluator (Ruby)
# on randomly generated cards and conditions, to catch combinations the
# hand-written shared examples miss. Uses a fixed seed so failures reproduce.
RSpec.describe "Card condition filtering parity" do
  let(:seed) { 20261004 }
  let(:card_count) { 150 }
  let(:condition_set_count) { 300 }

  let(:queries) do
    %w[
      IS_EMPTY IS_NOT_EMPTY EQUALS_VALUE DOES_NOT_EQUAL_VALUE CONTAINS
      DOES_NOT_CONTAIN IS_EMPTY_OR_EQUALS IS_CURRENT_MONTH IS_NOT_CURRENT_MONTH
      IS_PREVIOUS_MONTH IS_FUTURE IS_NOT_FUTURE IS_PAST IS_NOT_PAST
    ]
  end

  # Fields of each data type, plus one with no element (data type unknown)
  let(:field_types) { {"1" => "text", "2" => "date", "3" => "datetime", "4" => "choice", "5" => nil} }

  # :missing leaves the key (or option) out entirely, unlike nil (JSON null)
  let(:values) do
    [
      :missing, nil, "", " ", "abc", "ABC", "a", "Crème Brûlée", "100% done", "a_b", "5",
      "2024-03-01", "2024-03-31", "2024-04-01", "2024-02-29", "2024-02-01", "2023-03-15",
      "20240315", "not-a-date", "2024-03-31T22:59:59.999Z", "2024-03-31T23:00:00.001Z",
      "2024-03-31T18:30:00.000Z", "2024-02-29T18:30:00.000Z", "2024-04-01T00:00:00.000Z",
      5, true, {"lat" => "33.7", "lng" => "-84.4"}
    ]
  end

  let(:option_values) { [:missing, nil, "", "abc", "a", "A", "%", "_", "5", 5, "2024-03-01", "brûlée"] }

  let(:timezones) { ["UTC", "Asia/Kolkata", "America/New_York"] }

  let(:rng) { Random.new(seed) }
  let(:board) { FactoryBot.create(:board) }
  let(:elements_by_id) do
    field_types.compact.transform_values { |type| instance_double("Element", data_type: type) }
  end

  before { allow(Time).to receive(:now).and_return(Time.parse("2024-03-31 23:00:00 UTC")) }

  def random_card_values
    field_types.keys.each_with_object({}) do |field, card_values|
      value = values.sample(random: rng)
      card_values[field] = value unless value == :missing
    end
  end

  def random_conditions
    Array.new(rng.rand(1..3)) do
      condition = {"field" => field_types.keys.sample(random: rng), "query" => queries.sample(random: rng)}
      option = option_values.sample(random: rng)
      condition["options"] = {"value" => option} unless option == :missing
      condition
    end
  end

  it "returns the same cards from Ruby and SQL for random conditions" do
    cards = Array.new(card_count) do
      Card.create!(board:, user: board.user, field_values: random_card_values)
    end

    compared = 0
    condition_set_count.times do
      conditions = random_conditions
      timezone = timezones.sample(random: rng)

      # Cards the Ruby evaluator raises on are left out of the comparison;
      # those differences are covered in card_condition_query_spec.rb
      evaluator = CardConditionEvaluator.new(conditions, elements_by_id, timezone:)
      ruby_ids = []
      raised_ids = []
      cards.each do |card|
        ruby_ids << card.id if evaluator.passes?(card)
      rescue NoMethodError, TypeError, ArgumentError
        raised_ids << card.id
      end

      sql_ids = CardConditionQuery.new(conditions, elements_by_id, timezone:)
        .apply(board.cards).order(:id).pluck(:id) - raised_ids

      expect(sql_ids).to eq(ruby_ids), "conditions: #{conditions.inspect}, timezone: #{timezone}"
      compared += cards.size - raised_ids.size
    end

    # make sure the comparison isn't vacuous
    expect(compared).to be > card_count * condition_set_count / 2
  end
end
