class Field < ApplicationRecord
  enum :data_type,
    text: 0,
    datetime: 1
end
