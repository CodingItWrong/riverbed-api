FactoryBot.define do
  factory :column do
    user
    board
    sequence(:name) { |n| "Column #{n}" }
  end
end
