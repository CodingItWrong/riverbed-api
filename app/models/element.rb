class Element < ApplicationRecord
  belongs_to :board

  enum :element_type,
    field: 0,
    button: 1,
    button_menu: 2

  enum :data_type,
    text: 0,
    date: 1,
    number: 2,
    datetime: 3,
    choice: 4

  enum :initial_value,
    empty: 0,
    now: 1

  validates :element_type, presence: true
end
