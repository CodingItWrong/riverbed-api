# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :api_keys
  has_many :boards
  has_many :cards
  has_many :columns
  has_many :elements

  validates :email, presence: true, uniqueness: true
end
