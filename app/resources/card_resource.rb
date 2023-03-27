class CardResource < ApplicationResource
  attribute :field_values

  relationship :board, to: :one

  before_create do
    _model.user = current_user
  end

  def self.records(options = {}) = current_user(options).cards

  def self.creatable_fields(_context) = super - [:user]

  def self.updatable_fields(_context) = super - [:user, :board]
end
