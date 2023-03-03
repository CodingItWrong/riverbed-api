# frozen_string_literal: true

require "rails_helper"
require "link_parser"

RSpec.describe "custom links endpoint", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:url) { "https://example.com/blog/sample-post-title" }
  let(:headers) { {"Authorization" => "Bearer #{token}"} }
  let(:body) { {title: title, url: url} }
  let(:api_key) { FactoryBot.create(:api_key) }
  let(:board) { FactoryBot.create(:board, name: "Links") }
  let!(:url_field) { FactoryBot.create(:element, :field, board:, name: "URL") }
  let!(:title_field) { FactoryBot.create(:element, :field, board:, name: "Title") }
  let!(:saved_at_field) { FactoryBot.create(:element, :field, board:, data_type: :datetime, name: "Saved At") }
  let!(:read_status_changed_at_field) { FactoryBot.create(:element, :field, board:, data_type: :datetime, name: "Read Status Changed At") }

  let(:send!) { post custom_links_path, params: body, headers: headers }

  before(:each) do
    LinkParser.fake!
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
    let(:token) { api_key.key }

    context "immediately" do
      context "with a title" do
        let(:title) { "custom title" }

        it "does not create a link" do
          expect { send! }.not_to(change { Card.count })
        end

        it "returns accepted" do
          response = send!
          expect(response).to eq(204)
        end
      end
    end

    context "after job completes" do
      before(:each) do
        LinkParser.fake!
      end

      context "with a title" do
        let(:title) { "custom title" }
        let(:now) { Time.zone.now.iso8601 }

        around(:each) do |example|
          freeze_time do
            example.run
          end
        end

        it "creates a link" do
          expect {
            # note that this tests job delay, even though we've currently configured it to be immediate in production
            perform_enqueued_jobs { send! }
          }.to change { Card.count }.by(1)
        end

        it "keeps the passed-in title" do
          perform_enqueued_jobs { send! }
          card = Card.last
          expect(card.field_values).to eq(
            url_field.id.to_s => url,
            title_field.id.to_s => title,
            saved_at_field.id.to_s => now,
            read_status_changed_at_field.id.to_s => now
          )
        end
      end

      context "without a title" do
        let(:title) { "" }

        it "sets the title from the retrieved URL" do
          perform_enqueued_jobs { send! }
          title = Card.last.field_values[title_field.id.to_s]
          expect(title).to eq("Sample Post Title")
        end
      end

      context "with title equal to url" do
        let(:title) { url }

        it "assumes that was a default title and sets the title from the URL" do
          perform_enqueued_jobs { send! }
          title = Card.last.field_values[title_field.id.to_s]
          expect(title).to eq("Sample Post Title")
        end
      end
    end
  end
end
