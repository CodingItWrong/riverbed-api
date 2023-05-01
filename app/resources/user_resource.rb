class UserResource < ApplicationResource
  attributes :email, :password, :ios_share_board_id

  def self.fetchable_fields = super - [:email, :password]

  def self.records(options = {})
    User.where(id: current_user(options).id)
  end
end
