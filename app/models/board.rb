class Board < ApplicationRecord
  belongs_to :user
  has_many :cards, dependent: :destroy
  has_many :columns, dependent: :destroy
  has_many :elements, dependent: :destroy
end
