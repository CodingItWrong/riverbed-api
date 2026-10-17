# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardConditionEvaluator do
  def evaluator(conditions, elements_by_id = {}, timezone = "UTC")
    described_class.new(conditions, elements_by_id, timezone: timezone)
  end

  it_behaves_like "card condition filtering"
end
