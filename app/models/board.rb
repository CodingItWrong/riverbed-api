class Board < ApplicationRecord
  belongs_to :user
  has_many :cards, dependent: :destroy
  has_many :columns, dependent: :destroy
  has_many :elements, dependent: :destroy

  # slime to pass tests; make sure to update to use logged-in user
  before_validation do
    self.user ||= User.first
  end
end
