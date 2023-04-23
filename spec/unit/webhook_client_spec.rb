# TODO: not really a unit test
require "rails_helper"
require "webhook_client"

RSpec.describe WebhookClient do
  describe "#call" do
    let(:user) { FactoryBot.create(:user) }
    let(:board) { FactoryBot.create(:board, user:, board_options:) }
    let(:field) { FactoryBot.create(:element, :field, user:, board:) }
    let(:card) {
      FactoryBot.create(:card, user:, board:, field_values: {
        field.id.to_s => "Original Value"
      })
    }

    context "when a card update webhook is not configured" do
      let(:board_options) { {} }

      it "does not make a request to the webhook" do
        result = WebhookClient.new("card-update").call(card)

        expect(result).to be_nil
      end
    end

    context "when a card update webhook is configured" do
      let(:board_options) {
        {
          "webhooks" => {
            "card-update": "https://example.com/webhooks/test"
          }
        }
      }

      it "makes the correct request to the webhook and returns the response" do
        stub_request(:patch, "https://example.com/webhooks/test/#{card.id}")
          .with(body: {
            "field-values" => card.field_values,
            "elements" => [{
              "id" => field.id.to_s,
              "attributes" => {"name" => field.name}
            }]
          })
          .to_return(body: {
            field.id.to_s => "Updated Value"
          }.to_json)

        result = WebhookClient.new("card-update").call(card)

        expect(result).to eq(
          field.id.to_s => "Updated Value"
        )
      end
    end
  end
end
