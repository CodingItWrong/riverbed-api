class WebhookClient
  def card_update(card)
    url = card.board.board_options.dig("webhooks", "card-update")
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

  def httparty = HTTParty

  def headers = {"Content-Type": "application/json"}
end
