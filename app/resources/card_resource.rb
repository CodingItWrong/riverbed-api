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
    url = _model.board.board_options.dig("webhooks", "card-update")
    return if url.blank?

    body = {
      "field-values" => _model.field_values,
      "elements" => _model.board.elements.map { |elem|
        {
          "id" => elem.id.to_s,
          "attributes" => {"name" => elem.name} # TODO: all attributes
        }
      }
    }

    response = HTTParty.patch(
      "#{url}/#{_model.id}",
      headers: {"Content-Type": "application/json"},
      body: body.to_json
    )
    field_values_to_update = JSON.parse(response.body)

    _model.update!(field_values: _model.field_values.merge(field_values_to_update))
  end
end
