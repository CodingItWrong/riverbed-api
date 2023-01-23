class Board < ApplicationRecord
  has_many :cards
  has_many :columns
  has_many :elements
end
