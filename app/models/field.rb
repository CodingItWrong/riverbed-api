class Field < ApplicationRecord
  enum :data_type,
    text: 0,
    date: 1
end
