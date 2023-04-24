require "webhook_client"

class CardResource < ApplicationResource
  attribute :field_values

  relationship :board, to: :one

  before_create do
    _model.user = current_user
  end

  after_update do
    update_card_from_webhook
  end

  def self.records(options = {}) = current_user(options).cards

  def self.creatable_fields(_context) = super - [:user]

  def self.updatable_fields(_context) = super - [:user, :board]

  private

  def update_card_from_webhook
    field_values_to_update = WebhookClient.new("card-update").call(_model)
    if field_values_to_update.present?
      _model.update!(field_values: _model.field_values.merge(field_values_to_update))
    end
  end
end
