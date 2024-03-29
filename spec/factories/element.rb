FactoryBot.define do
  factory :element do
    user
    board

    trait :field do
      element_type { :field }
      data_type { :text }
    end

    trait :button do
      element_type { :button }
    end
  end
end
