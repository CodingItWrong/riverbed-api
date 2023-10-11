FactoryBot.define do
  factory :board do
    user
    sequence(:name) { |n| "Board #{n}" }
    icon { "link" }
  end
end
