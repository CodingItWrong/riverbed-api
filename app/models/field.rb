class Field < ApplicationRecord
  enum :data_type,
    text: 0,
    date: 1

  validates :name, presence: true
  validates :data_type, presence: true
end
