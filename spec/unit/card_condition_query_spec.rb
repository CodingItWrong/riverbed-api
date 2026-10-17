# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardConditionQuery do
  let(:board) { FactoryBot.create(:board) }

  def evaluator(conditions, elements_by_id = {}, timezone = "UTC")
    SqlConditionEvaluator.new(described_class.new(conditions, elements_by_id, timezone: timezone), board)
  end

  it_behaves_like "card condition filtering"

  # The only intended differences from CardConditionEvaluator: where the Ruby
  # evaluator raises (so the request returns a 500), the SQL version returns
  # a result instead, treating the value as not matching the condition.
  describe "where the Ruby evaluator raises" do
    let(:location) { {"lat" => "33.7", "lng" => "-84.4"} }

    def results_for(query, value, data_type: "text", options: {})
      conditions = [{"field" => "42", "query" => query, "options" => options}]
      elements = {"42" => instance_double("Element", data_type: data_type)}
      card = instance_double("Card", field_values: {"42" => value})
      ruby = begin
        CardConditionEvaluator.new(conditions, elements).passes?(card)
      rescue NoMethodError, TypeError, ArgumentError => e
        e.class
      end
      sql = evaluator(conditions, elements).passes?(card)
      [ruby, sql]
    end

    it "CONTAINS on an object value does not match" do
      ruby, sql = results_for("CONTAINS", location, options: {"value" => "33"})
      expect(ruby).to eq(NoMethodError)
      expect(sql).to be false
    end

    it "DOES_NOT_CONTAIN on an object value matches" do
      ruby, sql = results_for("DOES_NOT_CONTAIN", location, options: {"value" => "33"})
      expect(ruby).to eq(NoMethodError)
      expect(sql).to be true
    end

    it "CONTAINS with no search value does not match a non-empty value" do
      ruby, sql = results_for("CONTAINS", "abc")
      expect(ruby).to eq(NoMethodError)
      expect(sql).to be false
    end

    it "CONTAINS with a non-string search value does not match" do
      ruby, sql = results_for("CONTAINS", "abc", options: {"value" => 5})
      expect(ruby).to eq(NoMethodError)
      expect(sql).to be false
    end

    context "with date conditions" do
      before { allow(Time).to receive(:now).and_return(Time.parse("2024-03-15 12:00:00 UTC")) }

      it "IS_CURRENT_MONTH on an object value does not match" do
        ruby, sql = results_for("IS_CURRENT_MONTH", location, data_type: "date")
        expect(ruby).to eq(TypeError)
        expect(sql).to be false
      end

      it "IS_NOT_CURRENT_MONTH on an object value matches" do
        ruby, sql = results_for("IS_NOT_CURRENT_MONTH", location, data_type: "date")
        expect(ruby).to eq(TypeError)
        expect(sql).to be true
      end

      it "IS_PREVIOUS_MONTH on a number value does not match" do
        ruby, sql = results_for("IS_PREVIOUS_MONTH", 5, data_type: "date")
        expect(ruby).to eq(ArgumentError)
        expect(sql).to be false
      end

      it "IS_FUTURE on an object value does not match" do
        ruby, sql = results_for("IS_FUTURE", location, data_type: "date")
        expect(ruby).to eq(NoMethodError)
        expect(sql).to be false
      end

      it "IS_NOT_PAST on a number value matches" do
        ruby, sql = results_for("IS_NOT_PAST", 5, data_type: "datetime")
        expect(ruby).to eq(NoMethodError)
        expect(sql).to be true
      end
    end
  end

  it "uses bind parameters for field IDs and values" do
    conditions = [{"field" => "x' OR '1'='1", "query" => "EQUALS_VALUE", "options" => {"value" => "'; DROP TABLE cards; --"}}]
    matching = Card.create!(board:, user: board.user, field_values: {"x' OR '1'='1" => "'; DROP TABLE cards; --"})
    Card.create!(board:, user: board.user, field_values: {"x" => "y"})

    result = described_class.new(conditions, {}).apply(board.cards)

    expect(result.pluck(:id)).to eq([matching.id])
  end
end
