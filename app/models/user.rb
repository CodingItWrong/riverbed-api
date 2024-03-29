class User < ApplicationRecord
  has_secure_password

  has_many :api_keys
  has_many :boards
  has_many :cards
  has_many :columns
  has_many :elements
  belongs_to :ios_share_board, class_name: "Board", optional: true

  validates :email,
    presence: true,
    uniqueness: true,
    format: {
      with: /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/,
      message: "must be a valid email address"
    }

  validates :allow_emails, exclusion: [nil]
end
