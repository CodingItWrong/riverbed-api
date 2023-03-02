require 'securerandom'

class ApiKey < ApplicationRecord
  belongs_to :user

  before_create :initialize_key

  private

  def initialize_key
    self.key = SecureRandom.urlsafe_base64(64)
  end
end
