class WebhookClient
  def initialize(webhook_name)
    @webhook_name = webhook_name
  end

  def call(card)
    url = card.board.board_options.dig("webhooks", webhook_name)
    return if url.blank?

    body = {
      "field-values" => card.field_values,
      "elements" => card.board.elements.map { |elem|
        {
          "id" => elem.id.to_s,
          "attributes" => {"name" => elem.name} # TODO: all attributes
        }
      }
    }

    response = httparty.patch("#{url}/#{card.id}", headers:, body: body.to_json)
    JSON.parse(response.body)
  end

  private

  attr_reader :webhook_name

  def httparty = HTTParty

  def headers = {"Content-Type": "application/json"}
end
