class Element < ApplicationRecord
  enum :element_type,
    field: 0,
    button: 1

  enum :data_type,
    text: 0,
    date: 1

  validates :element_type, presence: true
end
