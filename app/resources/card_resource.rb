class CardResource < ApplicationResource
  attribute :field_values

  relationship :board, to: :one

  def self.records(options = {})
    user = current_user(options)
    Card.joins(board: :user).where("users.id": user.id)
  end

  def self.updatable_fields(context)
    super - [:board]
  end
end
