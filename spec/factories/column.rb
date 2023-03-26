FactoryBot.define do
  factory :column do
    board
    sequence(:name) { |n| "Column #{n}" }
  end
end
