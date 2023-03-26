# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :api_keys
  has_many :boards
  has_many :cards, through: :boards
  has_many :columns, through: :boards

  validates :email, presence: true, uniqueness: true
end
