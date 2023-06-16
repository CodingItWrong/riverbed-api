require "rails_helper"
require "link_parser"

RSpec.describe "iOS share endpoint", type: :request do
  include_context "with a logged in user"
  include ActiveSupport::Testing::TimeHelpers

  let(:headers) do
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end

  let(:url) { "https://example.com/blog/sample-post-title" }
  let(:body) { {title: title, url: url} }
  let(:user) { FactoryBot.create(:user) }
  let(:board) {
    FactoryBot.create(:board, name: "Custom Share Board", user:)
  }
  let(:webhooks) { {} }
  let!(:url_field) {
    FactoryBot.create(:element, :field, board:, user:, name: "URL")
  }
  let!(:title_field) {
    FactoryBot.create(:element, :field, board:, user:, name: "Title")
  }
  let!(:saved_at_field) {
    FactoryBot.create(:element, :field, board:, user:, data_type: :datetime, name: "Saved At")
  }
  let!(:read_status_changed_at_field) {
    FactoryBot.create(:element, :field, board:, user:, data_type: :datetime, name: "Read Status Changed At")
  }

  before(:each) do
    user.update!(ios_share_board: board)
    board.update!(board_options: {
      "share" => {
        "url-field" => url_field.id.to_s,
        "title-field" => title_field.id.to_s
      },
      "webhooks" => webhooks
    })
  end

  def send!
    post shares_path, params: body.to_json, headers: headers
  end

  context "with incorrect API token" do
    let(:token) { "bad_token" }
    let(:title) { "custom title" }

    it "does not create a link" do
      expect { send! }.not_to(change { Card.count })
    end

    it "returns unauthorized" do
      response = send!
      expect(response).to eq(401)
    end
  end

  context "with correct API token" do
    context "with no webhook configured" do
      let(:title) { "custom title" }

      it "saves the passed-in data as-is" do
        send!

        card = Card.last
        expect(card.field_values).to eq(
          url_field.id.to_s => url,
          title_field.id.to_s => title
        )
      end
    end

    context "with a webhook configured" do
      let(:webhooks) { {"card-create": "https://example.com/webhooks/test"} }

      let(:title) { "custom title" }
      let(:now) { Time.zone.now.iso8601 }

      around(:each) do |example|
        freeze_time do
          example.run
        end
      end

      it "saves the data returned by the webhook" do
        stub_request(:patch, %r{\Ahttps://example.com/webhooks/test/\d+\z})
          .to_return(body: {
            title_field.id.to_s => "Updated Value",
            saved_at_field.id.to_s => now,
            read_status_changed_at_field.id.to_s => now
          }.to_json)

        send!

        card = Card.last
        expect(card.field_values).to eq(
          url_field.id.to_s => url,
          title_field.id.to_s => "Updated Value",
          saved_at_field.id.to_s => now,
          read_status_changed_at_field.id.to_s => now
        )
      end
    end
  end
end
