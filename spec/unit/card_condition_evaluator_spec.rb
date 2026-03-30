# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardConditionEvaluator do
  # Minimal card double that responds to field_values
  def make_card(field_values = {})
    instance_double("Card", field_values: field_values)
  end

  # Build a simple element double with a data_type
  def make_element(data_type)
    instance_double("Element", data_type: data_type)
  end

  def evaluator(conditions, elements_by_id = {}, timezone = "UTC")
    described_class.new(conditions, elements_by_id, timezone: timezone)
  end

  # ---------------------------------------------------------------------------
  # Top-level evaluator behaviour
  # ---------------------------------------------------------------------------

  describe "top-level behaviour" do
    it "passes any card when conditions is nil" do
      expect(evaluator(nil).passes?(make_card)).to be true
    end

    it "passes any card when conditions is []" do
      expect(evaluator([]).passes?(make_card)).to be true
    end

    it "skips a condition missing the 'field' key" do
      cond = [{"query" => "IS_EMPTY"}]
      expect(evaluator(cond).passes?(make_card)).to be true
    end

    it "skips a condition missing the 'query' key" do
      cond = [{"field" => "1"}]
      expect(evaluator(cond, "1" => make_element("text")).passes?(make_card)).to be true
    end

    it "skips a condition with a blank 'field'" do
      cond = [{"field" => "", "query" => "IS_EMPTY"}]
      expect(evaluator(cond).passes?(make_card)).to be true
    end

    it "skips (and logs) an unknown query key" do
      allow(Rails.logger).to receive(:error)
      cond = [{"field" => "1", "query" => "UNKNOWN_OP"}]
      expect(evaluator(cond, "1" => make_element("text")).passes?(make_card)).to be true
      expect(Rails.logger).to have_received(:error).with(/unknown query key/)
    end

    it "returns true when all conditions pass" do
      cond = [
        {"field" => "1", "query" => "IS_EMPTY"},
        {"field" => "2", "query" => "IS_EMPTY"}
      ]
      elements = {"1" => make_element("text"), "2" => make_element("text")}
      expect(evaluator(cond, elements).passes?(make_card("1" => nil, "2" => nil))).to be true
    end

    it "short-circuits on the first failing condition" do
      cond = [
        {"field" => "1", "query" => "IS_EMPTY"},
        {"field" => "2", "query" => "IS_EMPTY"}
      ]
      elements = {"1" => make_element("text"), "2" => make_element("text")}
      # field 1 has a value → IS_EMPTY is false → short circuit
      expect(evaluator(cond, elements).passes?(make_card("1" => "oops"))).to be false
    end

    it "returns false when the last condition fails" do
      cond = [
        {"field" => "1", "query" => "IS_EMPTY"},
        {"field" => "2", "query" => "IS_EMPTY"}
      ]
      elements = {"1" => make_element("text"), "2" => make_element("text")}
      expect(evaluator(cond, elements).passes?(make_card("2" => "oops"))).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def single_cond(field_id, query, options = {})
    cond = {"field" => field_id, "query" => query}
    cond["options"] = options unless options.empty?
    [cond]
  end

  def eval_with(query, field_value, data_type: "text", options: {}, timezone: "UTC")
    field_id = "42"
    elements = {field_id => make_element(data_type)}
    fv = field_value.nil? ? {} : {field_id => field_value}
    evaluator(single_cond(field_id, query, options), elements, timezone).passes?(make_card(fv))
  end

  # ---------------------------------------------------------------------------
  # IS_EMPTY
  # ---------------------------------------------------------------------------

  describe "IS_EMPTY" do
    it { expect(eval_with("IS_EMPTY", nil)).to be true }
    it { expect(eval_with("IS_EMPTY", "")).to be true }
    it { expect(eval_with("IS_EMPTY", "hello")).to be false }
    it { expect(eval_with("IS_EMPTY", "0")).to be false }
    it "treats whitespace as non-empty" do
      expect(eval_with("IS_EMPTY", " ")).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # IS_NOT_EMPTY
  # ---------------------------------------------------------------------------

  describe "IS_NOT_EMPTY" do
    it { expect(eval_with("IS_NOT_EMPTY", nil)).to be false }
    it { expect(eval_with("IS_NOT_EMPTY", "")).to be false }
    it { expect(eval_with("IS_NOT_EMPTY", "hello")).to be true }
    it { expect(eval_with("IS_NOT_EMPTY", "0")).to be true }
  end

  # ---------------------------------------------------------------------------
  # EQUALS_VALUE
  # ---------------------------------------------------------------------------

  describe "EQUALS_VALUE" do
    it { expect(eval_with("EQUALS_VALUE", "approved", options: {"value" => "approved"})).to be true }
    it "is case-sensitive (Approved != approved)" do
      expect(eval_with("EQUALS_VALUE", "Approved", options: {"value" => "approved"})).to be false
    end
    it { expect(eval_with("EQUALS_VALUE", "approved", options: {"value" => "Approved"})).to be false }
    it { expect(eval_with("EQUALS_VALUE", "", options: {"value" => "approved"})).to be false }
    it { expect(eval_with("EQUALS_VALUE", nil, options: {"value" => "approved"})).to be false }
    it "empty equals empty" do
      expect(eval_with("EQUALS_VALUE", "", options: {"value" => ""})).to be true
    end
    it { expect(eval_with("EQUALS_VALUE", "a", options: {"value" => ""})).to be false }
  end

  # ---------------------------------------------------------------------------
  # DOES_NOT_EQUAL_VALUE
  # ---------------------------------------------------------------------------

  describe "DOES_NOT_EQUAL_VALUE" do
    it { expect(eval_with("DOES_NOT_EQUAL_VALUE", "approved", options: {"value" => "approved"})).to be false }
    it { expect(eval_with("DOES_NOT_EQUAL_VALUE", "Approved", options: {"value" => "approved"})).to be true }
    it { expect(eval_with("DOES_NOT_EQUAL_VALUE", "", options: {"value" => "approved"})).to be true }
    it { expect(eval_with("DOES_NOT_EQUAL_VALUE", nil, options: {"value" => "approved"})).to be true }
    it { expect(eval_with("DOES_NOT_EQUAL_VALUE", "", options: {"value" => ""})).to be false }
  end

  # ---------------------------------------------------------------------------
  # CONTAINS
  # ---------------------------------------------------------------------------

  describe "CONTAINS" do
    it { expect(eval_with("CONTAINS", "capybara", options: {"value" => "yba"})).to be true }
    it "is case-insensitive (Capybara contains YBA)" do
      expect(eval_with("CONTAINS", "Capybara", options: {"value" => "YBA"})).to be true
    end
    it { expect(eval_with("CONTAINS", "capybara", options: {"value" => "YBA"})).to be true }
    it { expect(eval_with("CONTAINS", "cat", options: {"value" => "yba"})).to be false }
    it { expect(eval_with("CONTAINS", nil, options: {"value" => "yba"})).to be false }
    it { expect(eval_with("CONTAINS", "", options: {"value" => "yba"})).to be false }
    it "empty search value always returns true for any field value" do
      expect(eval_with("CONTAINS", "anything", options: {"value" => ""})).to be true
    end
    it "empty search value returns true even when field is nil" do
      expect(eval_with("CONTAINS", nil, options: {"value" => ""})).to be true
    end
    it { expect(eval_with("CONTAINS", "", options: {"value" => ""})).to be true }
  end

  # ---------------------------------------------------------------------------
  # DOES_NOT_CONTAIN
  # ---------------------------------------------------------------------------

  describe "DOES_NOT_CONTAIN" do
    it { expect(eval_with("DOES_NOT_CONTAIN", "capybara", options: {"value" => "yba"})).to be false }
    it { expect(eval_with("DOES_NOT_CONTAIN", "Capybara", options: {"value" => "YBA"})).to be false }
    it { expect(eval_with("DOES_NOT_CONTAIN", "cat", options: {"value" => "yba"})).to be true }
    it { expect(eval_with("DOES_NOT_CONTAIN", nil, options: {"value" => "yba"})).to be true }
    it "inverse of CONTAINS when search is empty" do
      expect(eval_with("DOES_NOT_CONTAIN", "anything", options: {"value" => ""})).to be false
    end
    it { expect(eval_with("DOES_NOT_CONTAIN", nil, options: {"value" => ""})).to be false }
  end

  # ---------------------------------------------------------------------------
  # IS_EMPTY_OR_EQUALS
  # ---------------------------------------------------------------------------

  describe "IS_EMPTY_OR_EQUALS" do
    it { expect(eval_with("IS_EMPTY_OR_EQUALS", "", options: {"value" => "a"})).to be true }
    it { expect(eval_with("IS_EMPTY_OR_EQUALS", nil, options: {"value" => "a"})).to be true }
    it { expect(eval_with("IS_EMPTY_OR_EQUALS", "a", options: {"value" => "a"})).to be true }
    it { expect(eval_with("IS_EMPTY_OR_EQUALS", "b", options: {"value" => "a"})).to be false }
    it "is case-sensitive" do
      expect(eval_with("IS_EMPTY_OR_EQUALS", "A", options: {"value" => "a"})).to be false
    end
    it { expect(eval_with("IS_EMPTY_OR_EQUALS", "a", options: {"value" => ""})).to be false }
    it { expect(eval_with("IS_EMPTY_OR_EQUALS", "", options: {"value" => ""})).to be true }
  end

  # ---------------------------------------------------------------------------
  # Temporal helpers
  # ---------------------------------------------------------------------------

  def freeze_to(time_string)
    frozen = Time.parse(time_string + " UTC")
    allow(Time).to receive(:now).and_return(frozen)
  end

  # ---------------------------------------------------------------------------
  # IS_CURRENT_MONTH – date type
  # ---------------------------------------------------------------------------

  describe "IS_CURRENT_MONTH (date type, frozen to 2024-03-15)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_CURRENT_MONTH", "2024-03-01", data_type: "date")).to be true }
    it { expect(eval_with("IS_CURRENT_MONTH", "2024-03-15", data_type: "date")).to be true }
    it { expect(eval_with("IS_CURRENT_MONTH", "2024-03-31", data_type: "date")).to be true }
    it { expect(eval_with("IS_CURRENT_MONTH", "2024-02-28", data_type: "date")).to be false }
    it { expect(eval_with("IS_CURRENT_MONTH", "2024-04-01", data_type: "date")).to be false }
    it { expect(eval_with("IS_CURRENT_MONTH", "2023-03-15", data_type: "date")).to be false }
    it { expect(eval_with("IS_CURRENT_MONTH", nil, data_type: "date")).to be false }
    it { expect(eval_with("IS_CURRENT_MONTH", "", data_type: "date")).to be false }
    it { expect(eval_with("IS_CURRENT_MONTH", "not-a-date", data_type: "date")).to be false }
  end

  # ---------------------------------------------------------------------------
  # IS_CURRENT_MONTH – datetime type
  # ---------------------------------------------------------------------------

  describe "IS_CURRENT_MONTH (datetime type, frozen to 2024-03-15T12:00:00.000Z)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_CURRENT_MONTH", "2024-03-01T00:00:00.000Z", data_type: "datetime")).to be true }
    it { expect(eval_with("IS_CURRENT_MONTH", "2024-03-15T12:00:00.000Z", data_type: "datetime")).to be true }
    it { expect(eval_with("IS_CURRENT_MONTH", "2024-03-31T23:59:59.999Z", data_type: "datetime")).to be true }
    it { expect(eval_with("IS_CURRENT_MONTH", "2024-02-28T23:59:59.999Z", data_type: "datetime")).to be false }
    it { expect(eval_with("IS_CURRENT_MONTH", "2024-04-01T00:00:00.000Z", data_type: "datetime")).to be false }
    it { expect(eval_with("IS_CURRENT_MONTH", nil, data_type: "datetime")).to be false }
  end

  # ---------------------------------------------------------------------------
  # IS_CURRENT_MONTH – non-temporal types
  # ---------------------------------------------------------------------------

  describe "IS_CURRENT_MONTH (non-temporal types)" do
    before { freeze_to("2024-03-15 12:00:00") }

    %w[text number choice geolocation].each do |dt|
      it "returns false for data_type=#{dt}" do
        expect(eval_with("IS_CURRENT_MONTH", "2024-03-15", data_type: dt)).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # IS_NOT_CURRENT_MONTH – date type
  # ---------------------------------------------------------------------------

  describe "IS_NOT_CURRENT_MONTH (date type, frozen to 2024-03-15)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_NOT_CURRENT_MONTH", "2024-03-15", data_type: "date")).to be false }
    it { expect(eval_with("IS_NOT_CURRENT_MONTH", "2024-02-28", data_type: "date")).to be true }
    it { expect(eval_with("IS_NOT_CURRENT_MONTH", "2024-04-01", data_type: "date")).to be true }
    it "nil: inverse of IS_CURRENT_MONTH(nil)=false → true" do
      expect(eval_with("IS_NOT_CURRENT_MONTH", nil, data_type: "date")).to be true
    end
    it { expect(eval_with("IS_NOT_CURRENT_MONTH", "", data_type: "date")).to be true }
  end

  # ---------------------------------------------------------------------------
  # IS_NOT_CURRENT_MONTH – non-temporal types
  # ---------------------------------------------------------------------------

  describe "IS_NOT_CURRENT_MONTH (non-temporal types)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it "returns false for text" do
      expect(eval_with("IS_NOT_CURRENT_MONTH", "2024-03-15", data_type: "text")).to be false
    end
    it "returns false for number" do
      expect(eval_with("IS_NOT_CURRENT_MONTH", "2024-03-15", data_type: "number")).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # IS_NOT_CURRENT_MONTH – datetime type
  # ---------------------------------------------------------------------------

  describe "IS_NOT_CURRENT_MONTH (datetime type, frozen to 2024-03-15)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_NOT_CURRENT_MONTH", "2024-03-15T12:00:00.000Z", data_type: "datetime")).to be false }
    it { expect(eval_with("IS_NOT_CURRENT_MONTH", "2024-03-01T00:00:00.000Z", data_type: "datetime")).to be false }
    it { expect(eval_with("IS_NOT_CURRENT_MONTH", "2024-02-28T23:59:59.999Z", data_type: "datetime")).to be true }
    it { expect(eval_with("IS_NOT_CURRENT_MONTH", "2024-04-01T00:00:00.000Z", data_type: "datetime")).to be true }
    it "nil: inverse of IS_CURRENT_MONTH(nil)=false → true" do
      expect(eval_with("IS_NOT_CURRENT_MONTH", nil, data_type: "datetime")).to be true
    end
    it { expect(eval_with("IS_NOT_CURRENT_MONTH", "", data_type: "datetime")).to be true }
  end

  # ---------------------------------------------------------------------------
  # IS_PREVIOUS_MONTH – date type
  # ---------------------------------------------------------------------------

  describe "IS_PREVIOUS_MONTH (date type, frozen to 2024-03-15)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-01", data_type: "date")).to be true }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-15", data_type: "date")).to be true }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-29", data_type: "date")).to be true }
    it "boundary: current month start is excluded" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-03-01", data_type: "date")).to be false
    end
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-01-31", data_type: "date")).to be false }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-03-15", data_type: "date")).to be false }
    it { expect(eval_with("IS_PREVIOUS_MONTH", nil, data_type: "date")).to be false }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "", data_type: "date")).to be false }
  end

  describe "IS_PREVIOUS_MONTH year boundary (frozen to 2024-01-15)" do
    before { freeze_to("2024-01-15 12:00:00") }

    it { expect(eval_with("IS_PREVIOUS_MONTH", "2023-12-31", data_type: "date")).to be true }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-01-01", data_type: "date")).to be false }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2023-11-30", data_type: "date")).to be false }
  end

  describe "IS_PREVIOUS_MONTH (non-temporal types)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it "returns false for text" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-15", data_type: "text")).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # IS_PREVIOUS_MONTH – datetime type
  # ---------------------------------------------------------------------------

  describe "IS_PREVIOUS_MONTH (datetime type, frozen to 2024-03-15)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-01T00:00:00.000Z", data_type: "datetime")).to be true }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-15T12:00:00.000Z", data_type: "datetime")).to be true }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-29T23:59:59.999Z", data_type: "datetime")).to be true }
    it "boundary: current month start is excluded" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-03-01T00:00:00.000Z", data_type: "datetime")).to be false
    end
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-01-31T23:59:59.999Z", data_type: "datetime")).to be false }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-03-15T12:00:00.000Z", data_type: "datetime")).to be false }
    it { expect(eval_with("IS_PREVIOUS_MONTH", nil, data_type: "datetime")).to be false }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "", data_type: "datetime")).to be false }
  end

  describe "IS_PREVIOUS_MONTH (datetime type, year boundary, frozen to 2024-01-15)" do
    before { freeze_to("2024-01-15 12:00:00") }

    it { expect(eval_with("IS_PREVIOUS_MONTH", "2023-12-31T23:59:59.999Z", data_type: "datetime")).to be true }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2023-12-01T00:00:00.000Z", data_type: "datetime")).to be true }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2024-01-01T00:00:00.000Z", data_type: "datetime")).to be false }
    it { expect(eval_with("IS_PREVIOUS_MONTH", "2023-11-30T23:59:59.999Z", data_type: "datetime")).to be false }
  end

  # ---------------------------------------------------------------------------
  # IS_FUTURE – date type
  # ---------------------------------------------------------------------------

  describe "IS_FUTURE (date type, frozen to 2024-03-15)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_FUTURE", "2024-03-16", data_type: "date")).to be true }
    it "today is not future" do
      expect(eval_with("IS_FUTURE", "2024-03-15", data_type: "date")).to be false
    end
    it { expect(eval_with("IS_FUTURE", "2024-03-14", data_type: "date")).to be false }
    it { expect(eval_with("IS_FUTURE", "2025-01-01", data_type: "date")).to be true }
    it { expect(eval_with("IS_FUTURE", nil, data_type: "date")).to be false }
    it { expect(eval_with("IS_FUTURE", "", data_type: "date")).to be false }
    it "invalid string (lex < any date) is not future" do
      expect(eval_with("IS_FUTURE", "not-a-date", data_type: "date")).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # IS_FUTURE – datetime type
  # ---------------------------------------------------------------------------

  describe "IS_FUTURE (datetime type, frozen to 2024-03-15T12:00:00.000Z)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_FUTURE", "2024-03-15T12:00:00.001Z", data_type: "datetime")).to be true }
    it "exact now is not future" do
      expect(eval_with("IS_FUTURE", "2024-03-15T12:00:00.000Z", data_type: "datetime")).to be false
    end
    it { expect(eval_with("IS_FUTURE", "2024-03-15T11:59:59.999Z", data_type: "datetime")).to be false }
    it { expect(eval_with("IS_FUTURE", nil, data_type: "datetime")).to be false }
    it { expect(eval_with("IS_FUTURE", "", data_type: "datetime")).to be false }
  end

  # ---------------------------------------------------------------------------
  # IS_FUTURE – non-temporal types
  # ---------------------------------------------------------------------------

  describe "IS_FUTURE (non-temporal types)" do
    before { freeze_to("2024-03-15 12:00:00") }

    %w[text number choice].each do |dt|
      it "returns false for data_type=#{dt}" do
        expect(eval_with("IS_FUTURE", "2024-03-16", data_type: dt)).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # IS_NOT_FUTURE – date type
  # ---------------------------------------------------------------------------

  describe "IS_NOT_FUTURE (date type, frozen to 2024-03-15)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_NOT_FUTURE", "2024-03-16", data_type: "date")).to be false }
    it "today is not future, so IS_NOT_FUTURE is true" do
      expect(eval_with("IS_NOT_FUTURE", "2024-03-15", data_type: "date")).to be true
    end
    it { expect(eval_with("IS_NOT_FUTURE", "2024-03-14", data_type: "date")).to be true }
    it "nil: inverse of IS_FUTURE(nil)=false → true" do
      expect(eval_with("IS_NOT_FUTURE", nil, data_type: "date")).to be true
    end
  end

  describe "IS_NOT_FUTURE (non-temporal types)" do
    it "returns false for text" do
      expect(eval_with("IS_NOT_FUTURE", "2024-03-14", data_type: "text")).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # IS_NOT_FUTURE – datetime type
  # ---------------------------------------------------------------------------

  describe "IS_NOT_FUTURE (datetime type, frozen to 2024-03-15T12:00:00.000Z)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_NOT_FUTURE", "2024-03-15T12:00:00.001Z", data_type: "datetime")).to be false }
    it "exact now is not future, so IS_NOT_FUTURE is true" do
      expect(eval_with("IS_NOT_FUTURE", "2024-03-15T12:00:00.000Z", data_type: "datetime")).to be true
    end
    it { expect(eval_with("IS_NOT_FUTURE", "2024-03-15T11:59:59.999Z", data_type: "datetime")).to be true }
    it "nil: inverse of IS_FUTURE(nil)=false → true" do
      expect(eval_with("IS_NOT_FUTURE", nil, data_type: "datetime")).to be true
    end
    it { expect(eval_with("IS_NOT_FUTURE", "", data_type: "datetime")).to be true }
  end

  # ---------------------------------------------------------------------------
  # IS_PAST – date type
  # ---------------------------------------------------------------------------

  describe "IS_PAST (date type, frozen to 2024-03-15)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_PAST", "2024-03-14", data_type: "date")).to be true }
    it "today is not past" do
      expect(eval_with("IS_PAST", "2024-03-15", data_type: "date")).to be false
    end
    it { expect(eval_with("IS_PAST", "2024-03-16", data_type: "date")).to be false }
    it { expect(eval_with("IS_PAST", "2020-01-01", data_type: "date")).to be true }
    it { expect(eval_with("IS_PAST", nil, data_type: "date")).to be false }
    it { expect(eval_with("IS_PAST", "", data_type: "date")).to be false }
  end

  # ---------------------------------------------------------------------------
  # IS_PAST – datetime type
  # ---------------------------------------------------------------------------

  describe "IS_PAST (datetime type, frozen to 2024-03-15T12:00:00.000Z)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_PAST", "2024-03-15T11:59:59.999Z", data_type: "datetime")).to be true }
    it "exact now is not past" do
      expect(eval_with("IS_PAST", "2024-03-15T12:00:00.000Z", data_type: "datetime")).to be false
    end
    it { expect(eval_with("IS_PAST", "2024-03-15T12:00:00.001Z", data_type: "datetime")).to be false }
    it { expect(eval_with("IS_PAST", nil, data_type: "datetime")).to be false }
    it { expect(eval_with("IS_PAST", "", data_type: "datetime")).to be false }
  end

  # ---------------------------------------------------------------------------
  # IS_PAST – non-temporal types
  # ---------------------------------------------------------------------------

  describe "IS_PAST (non-temporal types)" do
    before { freeze_to("2024-03-15 12:00:00") }

    %w[text number choice].each do |dt|
      it "returns false for data_type=#{dt}" do
        expect(eval_with("IS_PAST", "2024-03-14", data_type: dt)).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # IS_NOT_PAST – date type
  # ---------------------------------------------------------------------------

  describe "IS_NOT_PAST (date type, frozen to 2024-03-15)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_NOT_PAST", "2024-03-14", data_type: "date")).to be false }
    it "today is not past, so IS_NOT_PAST is true" do
      expect(eval_with("IS_NOT_PAST", "2024-03-15", data_type: "date")).to be true
    end
    it { expect(eval_with("IS_NOT_PAST", "2024-03-16", data_type: "date")).to be true }
    it "nil: inverse of IS_PAST(nil)=false → true" do
      expect(eval_with("IS_NOT_PAST", nil, data_type: "date")).to be true
    end
  end

  describe "IS_NOT_PAST (non-temporal types)" do
    it "returns false for text" do
      expect(eval_with("IS_NOT_PAST", "2024-03-16", data_type: "text")).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # IS_NOT_PAST – datetime type
  # ---------------------------------------------------------------------------

  describe "IS_NOT_PAST (datetime type, frozen to 2024-03-15T12:00:00.000Z)" do
    before { freeze_to("2024-03-15 12:00:00") }

    it { expect(eval_with("IS_NOT_PAST", "2024-03-15T11:59:59.999Z", data_type: "datetime")).to be false }
    it "exact now is not past, so IS_NOT_PAST is true" do
      expect(eval_with("IS_NOT_PAST", "2024-03-15T12:00:00.000Z", data_type: "datetime")).to be true
    end
    it { expect(eval_with("IS_NOT_PAST", "2024-03-15T12:00:00.001Z", data_type: "datetime")).to be true }
    it "nil: inverse of IS_PAST(nil)=false → true" do
      expect(eval_with("IS_NOT_PAST", nil, data_type: "datetime")).to be true
    end
    it { expect(eval_with("IS_NOT_PAST", "", data_type: "datetime")).to be true }
  end

  # ---------------------------------------------------------------------------
  # Timezone-aware filtering (date fields only)
  # Frozen UTC: 2024-03-31 23:00:00
  # UTC date: 2024-03-31 (March)
  # Asia/Kolkata (UTC+5:30) date: 2024-04-01 (April)
  # ---------------------------------------------------------------------------

  describe "timezone-aware IS_FUTURE (date type)" do
    # UTC 2024-03-14 23:00:00 → Kolkata (UTC+5:30) date = 2024-03-15
    # UTC date = 2024-03-14
    before { freeze_to("2024-03-14 23:00:00") }

    it "2024-03-15 IS_FUTURE with UTC (UTC date is 2024-03-14)" do
      expect(eval_with("IS_FUTURE", "2024-03-15", data_type: "date", timezone: "UTC")).to be true
    end

    it "2024-03-15 is NOT IS_FUTURE with Asia/Kolkata (local date is already 2024-03-15 = today)" do
      expect(eval_with("IS_FUTURE", "2024-03-15", data_type: "date", timezone: "Asia/Kolkata")).to be false
    end
  end

  describe "timezone-aware IS_PAST (date type)" do
    # UTC 2024-03-14 23:00:00 → Kolkata (UTC+5:30) date = 2024-03-15
    # UTC date = 2024-03-14
    before { freeze_to("2024-03-14 23:00:00") }

    it "2024-03-14 IS_PAST with UTC (UTC date is 2024-03-14 = today, NOT past)" do
      expect(eval_with("IS_PAST", "2024-03-14", data_type: "date", timezone: "UTC")).to be false
    end

    it "2024-03-14 IS_PAST with Asia/Kolkata (local date is 2024-03-15, so 2024-03-14 is past)" do
      expect(eval_with("IS_PAST", "2024-03-14", data_type: "date", timezone: "Asia/Kolkata")).to be true
    end
  end

  describe "timezone-aware IS_CURRENT_MONTH (date type)" do
    # UTC 2024-03-31 23:00:00 → Kolkata (UTC+5:30) date = 2024-04-01 (April)
    # UTC date = 2024-03-31 (March)
    before { freeze_to("2024-03-31 23:00:00") }

    it "2024-03-31 IS_CURRENT_MONTH with UTC (UTC month is March)" do
      expect(eval_with("IS_CURRENT_MONTH", "2024-03-31", data_type: "date", timezone: "UTC")).to be true
    end

    it "2024-03-31 is NOT IS_CURRENT_MONTH with Asia/Kolkata (local month is April)" do
      expect(eval_with("IS_CURRENT_MONTH", "2024-03-31", data_type: "date", timezone: "Asia/Kolkata")).to be false
    end

    it "2024-04-01 is NOT IS_CURRENT_MONTH with UTC (UTC month is March)" do
      expect(eval_with("IS_CURRENT_MONTH", "2024-04-01", data_type: "date", timezone: "UTC")).to be false
    end

    it "2024-04-01 IS_CURRENT_MONTH with Asia/Kolkata (local month is April)" do
      expect(eval_with("IS_CURRENT_MONTH", "2024-04-01", data_type: "date", timezone: "Asia/Kolkata")).to be true
    end
  end

  describe "timezone-aware IS_PREVIOUS_MONTH (date type)" do
    # UTC 2024-03-31 23:00:00 → Kolkata (UTC+5:30) date = 2024-04-01 (April)
    # UTC date = 2024-03-31 (March), previous month = February
    # Kolkata date = 2024-04-01 (April), previous month = March
    before { freeze_to("2024-03-31 23:00:00") }

    it "2024-02-15 IS_PREVIOUS_MONTH with UTC (previous month is February)" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-15", data_type: "date", timezone: "UTC")).to be true
    end

    it "2024-02-15 is NOT IS_PREVIOUS_MONTH with Asia/Kolkata (previous month is March)" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-15", data_type: "date", timezone: "Asia/Kolkata")).to be false
    end

    it "2024-03-15 is NOT IS_PREVIOUS_MONTH with UTC (previous month is February, not March)" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-03-15", data_type: "date", timezone: "UTC")).to be false
    end

    it "2024-03-15 IS_PREVIOUS_MONTH with Asia/Kolkata (previous month is March)" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-03-15", data_type: "date", timezone: "Asia/Kolkata")).to be true
    end
  end

  describe "timezone does not affect datetime IS_FUTURE" do
    # For datetime fields, UTC comparisons are used regardless of timezone
    before { freeze_to("2024-03-15 12:00:00") }

    it "datetime IS_FUTURE is the same with UTC and with a different timezone" do
      future_val = "2024-03-15T12:00:00.001Z"
      expect(eval_with("IS_FUTURE", future_val, data_type: "datetime", timezone: "UTC")).to be true
      expect(eval_with("IS_FUTURE", future_val, data_type: "datetime", timezone: "Asia/Kolkata")).to be true
    end

    it "datetime IS_FUTURE past value is false with any timezone" do
      past_val = "2024-03-15T11:59:59.999Z"
      expect(eval_with("IS_FUTURE", past_val, data_type: "datetime", timezone: "UTC")).to be false
      expect(eval_with("IS_FUTURE", past_val, data_type: "datetime", timezone: "Asia/Kolkata")).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # Timezone-aware IS_CURRENT_MONTH (datetime type)
  # Frozen UTC: 2024-03-31 23:00:00
  # UTC month: March — UTC month start is "2024-03-01T00:00:00.000Z"
  # Asia/Kolkata (UTC+5:30) month: April — Kolkata April start in UTC is "2024-03-31T18:30:00.000Z"
  # ---------------------------------------------------------------------------

  describe "timezone-aware IS_CURRENT_MONTH (datetime type)" do
    before { freeze_to("2024-03-31 23:00:00") }

    it "2024-04-01T00:00:00.000Z is NOT IS_CURRENT_MONTH with UTC (UTC month is March)" do
      expect(eval_with("IS_CURRENT_MONTH", "2024-04-01T00:00:00.000Z", data_type: "datetime", timezone: "UTC")).to be false
    end

    it "2024-04-01T00:00:00.000Z IS_CURRENT_MONTH with Asia/Kolkata (Kolkata month is April)" do
      expect(eval_with("IS_CURRENT_MONTH", "2024-04-01T00:00:00.000Z", data_type: "datetime", timezone: "Asia/Kolkata")).to be true
    end

    it "2024-03-31T18:30:00.000Z (April 1 00:00 IST) IS_CURRENT_MONTH with Asia/Kolkata" do
      expect(eval_with("IS_CURRENT_MONTH", "2024-03-31T18:30:00.000Z", data_type: "datetime", timezone: "Asia/Kolkata")).to be true
    end

    it "2024-03-31T18:29:59.999Z (March 31 23:59 IST) is NOT IS_CURRENT_MONTH with Asia/Kolkata" do
      expect(eval_with("IS_CURRENT_MONTH", "2024-03-31T18:29:59.999Z", data_type: "datetime", timezone: "Asia/Kolkata")).to be false
    end

    it "2024-03-31T23:00:00.000Z IS_CURRENT_MONTH with UTC (still March in UTC)" do
      expect(eval_with("IS_CURRENT_MONTH", "2024-03-31T23:00:00.000Z", data_type: "datetime", timezone: "UTC")).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Timezone-aware IS_PREVIOUS_MONTH (datetime type)
  # Frozen UTC: 2024-03-31 23:00:00
  # UTC previous month: February
  # Asia/Kolkata previous month: March (current month is April in Kolkata)
  # Kolkata March start in UTC: "2024-02-29T18:30:00.000Z" (2024 is a leap year)
  # Kolkata April start in UTC: "2024-03-31T18:30:00.000Z"
  # ---------------------------------------------------------------------------

  describe "timezone-aware IS_PREVIOUS_MONTH (datetime type)" do
    before { freeze_to("2024-03-31 23:00:00") }

    it "2024-02-15T12:00:00.000Z IS_PREVIOUS_MONTH with UTC (previous UTC month is February)" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-15T12:00:00.000Z", data_type: "datetime", timezone: "UTC")).to be true
    end

    it "2024-02-15T12:00:00.000Z is NOT IS_PREVIOUS_MONTH with Asia/Kolkata (previous Kolkata month is March)" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-02-15T12:00:00.000Z", data_type: "datetime", timezone: "Asia/Kolkata")).to be false
    end

    it "2024-03-15T12:00:00.000Z is NOT IS_PREVIOUS_MONTH with UTC (previous UTC month is February, not March)" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-03-15T12:00:00.000Z", data_type: "datetime", timezone: "UTC")).to be false
    end

    it "2024-03-15T12:00:00.000Z IS_PREVIOUS_MONTH with Asia/Kolkata (previous Kolkata month is March)" do
      expect(eval_with("IS_PREVIOUS_MONTH", "2024-03-15T12:00:00.000Z", data_type: "datetime", timezone: "Asia/Kolkata")).to be true
    end
  end
end
