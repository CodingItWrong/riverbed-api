FactoryBot.define do
  factory :board do
    sequence(:name) { |n| "Board #{n}" }
  end
end
