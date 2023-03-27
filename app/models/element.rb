class Element < ApplicationRecord
  belongs_to :board
  belongs_to :user # direct user reference necessary for JR

  enum :element_type,
    field: 0,
    button: 1,
    button_menu: 2

  enum :data_type,
    text: 0,
    date: 1,
    number: 2,
    datetime: 3,
    choice: 4,
    geolocation: 5

  enum :initial_value,
    empty: 0,
    now: 1

  validates :element_type, presence: true
  validates :board, belongs_to_user: true
end
