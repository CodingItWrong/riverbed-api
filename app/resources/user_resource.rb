class UserResource < ApplicationResource
  attributes :email, :password, :allow_emails, :ios_share_board_id

  def fetchable_fields = super - [:email, :password]

  def self.records(options = {})
    User.where(id: current_user(options).id)
  end
end
