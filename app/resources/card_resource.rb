class CardResource < ApplicationResource
  attribute :field_values

  relationship :board, to: :one

  before_create do
    _model.user = current_user
  end

  def self.records(options = {})
    user = current_user(options)
    user.cards
  end

  def self.creatable_fields(context)
    super - [:user]
  end

  def self.updatable_fields(context)
    super - [:user, :board]
  end
end
