# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /columns/:id/cards" do
  include_context "with a logged in user"

  let!(:board) { FactoryBot.create(:board, user:) }
  let!(:column) { FactoryBot.create(:column, board:, user:) }
  let(:response_body) { JSON.parse(response.body) }

  context "when logged out" do
    it "returns 401 with empty body" do
      get "/columns/#{column.id}/cards"

      expect(response.status).to eq(401)
      expect(response.body).to be_empty
    end
  end

  context "when logged in" do
    context "with a column belonging to another user" do
      let!(:other_user) { FactoryBot.create(:user) }
      let!(:other_board) { FactoryBot.create(:board, user: other_user) }
      let!(:other_column) { FactoryBot.create(:column, board: other_board, user: other_user) }

      it "returns 404 with JSON:API error structure" do
        get "/columns/#{other_column.id}/cards", headers: headers

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end
    end

    context "with a non-existent column ID" do
      it "returns 404" do
        get "/columns/0/cards", headers: headers

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
      end
    end

    context "with empty card_inclusion_conditions" do
      let!(:card1) { FactoryBot.create(:card, board:, user:) }
      let!(:card2) { FactoryBot.create(:card, board:, user:) }

      before { column.update!(card_inclusion_conditions: []) }

      it "returns all board cards" do
        get "/columns/#{column.id}/cards", headers: headers

        expect(response.status).to eq(200)
        expect(response_body["data"].map { |c| c["id"] }).to contain_exactly(
          card1.id.to_s, card2.id.to_s
        )
      end
    end

    context "with an IS_NOT_EMPTY condition" do
      let!(:field) { FactoryBot.create(:element, :field, board:, user:) }
      let!(:filled_card) { FactoryBot.create(:card, board:, user:, field_values: {field.id.to_s => "hello"}) }
      let!(:empty_card) { FactoryBot.create(:card, board:, user:, field_values: {}) }

      before do
        column.update!(card_inclusion_conditions: [
          {"field" => field.id.to_s, "query" => "IS_NOT_EMPTY"}
        ])
      end

      it "returns only the filled card" do
        get "/columns/#{column.id}/cards", headers: headers

        expect(response.status).to eq(200)
        expect(response_body["data"].map { |c| c["id"] }).to contain_exactly(filled_card.id.to_s)
      end
    end

    context "with two AND conditions" do
      let!(:field_a) { FactoryBot.create(:element, :field, board:, user:) }
      let!(:field_b) { FactoryBot.create(:element, :field, board:, user:) }

      let!(:card_both) do
        FactoryBot.create(:card, board:, user:,
          field_values: {field_a.id.to_s => "yes", field_b.id.to_s => "yes"})
      end
      let!(:card_only_a) do
        FactoryBot.create(:card, board:, user:,
          field_values: {field_a.id.to_s => "yes", field_b.id.to_s => ""})
      end
      let!(:card_only_b) do
        FactoryBot.create(:card, board:, user:,
          field_values: {field_a.id.to_s => "", field_b.id.to_s => "yes"})
      end
      let!(:card_neither) do
        FactoryBot.create(:card, board:, user:, field_values: {})
      end

      before do
        column.update!(card_inclusion_conditions: [
          {"field" => field_a.id.to_s, "query" => "IS_NOT_EMPTY"},
          {"field" => field_b.id.to_s, "query" => "IS_NOT_EMPTY"}
        ])
      end

      it "returns only cards satisfying both conditions" do
        get "/columns/#{column.id}/cards", headers: headers

        expect(response.status).to eq(200)
        expect(response_body["data"].map { |c| c["id"] }).to contain_exactly(card_both.id.to_s)
      end
    end

    context "response format" do
      let!(:field) { FactoryBot.create(:element, :field, board:, user:) }
      let!(:card) { FactoryBot.create(:card, board:, user:, field_values: {field.id.to_s => "val"}) }

      it "returns 200 with correct content type and JSON:API structure" do
        get "/columns/#{column.id}/cards", headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("data")
        expect(response_body["data"]).to be_an(Array)

        card_data = response_body["data"].first
        expect(card_data["type"]).to eq("cards")
        expect(card_data["id"]).to eq(card.id.to_s)
        expect(card_data["attributes"]).to have_key("field-values")
      end
    end

    context "cross-board isolation" do
      let!(:other_board) { FactoryBot.create(:board, user:) }
      let!(:other_card) { FactoryBot.create(:card, board: other_board, user:) }
      let!(:this_card) { FactoryBot.create(:card, board:, user:) }

      it "never returns cards from other boards" do
        get "/columns/#{column.id}/cards", headers: headers

        expect(response.status).to eq(200)
        ids = response_body["data"].map { |c| c["id"] }
        expect(ids).to include(this_card.id.to_s)
        expect(ids).not_to include(other_card.id.to_s)
      end
    end

    context "timezone parameter" do
      let!(:date_field) { FactoryBot.create(:element, :field, board:, user:, data_type: :date) }

      before do
        column.update!(card_inclusion_conditions: [
          {"field" => date_field.id.to_s, "query" => "IS_CURRENT_MONTH"}
        ])
        # Freeze UTC to 2024-03-31 23:00:00
        # UTC date: 2024-03-31 (March) — march_card is current month
        # Asia/Kolkata (UTC+5:30) date: 2024-04-01 (April) — april_card is current month
        frozen = Time.parse("2024-03-31 23:00:00 UTC")
        allow(Time).to receive(:now).and_return(frozen)
      end

      let!(:march_card) do
        FactoryBot.create(:card, board:, user:, field_values: {date_field.id.to_s => "2024-03-31"})
      end
      let!(:april_card) do
        FactoryBot.create(:card, board:, user:, field_values: {date_field.id.to_s => "2024-04-01"})
      end

      context "without timezone param (defaults to UTC)" do
        it "filters using UTC date: March is current month" do
          get "/columns/#{column.id}/cards", headers: headers

          expect(response.status).to eq(200)
          ids = response_body["data"].map { |c| c["id"] }
          expect(ids).to include(march_card.id.to_s)
          expect(ids).not_to include(april_card.id.to_s)
        end
      end

      context "with timezone=Asia/Kolkata (UTC+5:30)" do
        it "filters using Kolkata date: April is current month" do
          get "/columns/#{column.id}/cards?timezone=Asia%2FKolkata", headers: headers

          expect(response.status).to eq(200)
          ids = response_body["data"].map { |c| c["id"] }
          expect(ids).to include(april_card.id.to_s)
          expect(ids).not_to include(march_card.id.to_s)
        end
      end

      context "with an invalid timezone" do
        it "returns 422 with JSON:API error structure" do
          get "/columns/#{column.id}/cards?timezone=Not%2FATimezone", headers: headers

          expect(response.status).to eq(422)
          expect(response.content_type).to start_with("application/vnd.api+json")
          expect(response_body["errors"]).to include(a_hash_including(
            "title" => "Invalid timezone"
          ))
        end
      end
    end
  end
end
