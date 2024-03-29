require "rails_helper"

RSpec.describe "cards" do
  include_context "with a logged in user"

  let!(:user_board) { FactoryBot.create(:board, user:) }
  let!(:user_field) { FactoryBot.create(:element, :field, board: user_board, user:) }
  let!(:user_card) { FactoryBot.create(:card, board: user_board, user:) }

  let!(:other_user) { FactoryBot.create(:user) }
  let!(:other_user_board) { FactoryBot.create(:board, user: other_user) }
  let!(:other_user_field) { FactoryBot.create(:element, :field, board: other_user_board, user: other_user) }
  let!(:other_user_card) { FactoryBot.create(:card, board: other_user_board, user: other_user) }
  let(:response_body) { JSON.parse(response.body) }

  describe "GET /boards/:id/cards" do
    it "returns cards for a board belonging to the user" do
      # debugger
      get "/boards/#{user_board.id}/cards", headers: headers

      expect(response.status).to eq(200)
      expect(response_body["data"]).to contain_exactly(
        a_hash_including(
          "type" => "cards",
          "id" => user_card.id.to_s
        )
      )
    end

    it "does not return cards for a board belonging to another user" do
      get "/boards/#{other_user_board.id}/cards", headers: headers

      expect(response.status).to eq(404)
    end
  end

  describe "GET /cards/:id" do
    it "returns a card for a board belonging to the user" do
      get "/cards/#{user_card.id}", headers: headers

      expect(response.status).to eq(200)
      expect(response_body["data"]).to include(
        "type" => "cards",
        "id" => user_card.id.to_s
      )
    end

    it "does not return a card for a board belonging to another user" do
      get "/cards/#{other_user_card.id}", headers: headers

      expect(response.status).to eq(404)
    end
  end

  describe "POST /cards" do
    it "creates a card on a board belonging to the user" do
      params = {
        data: {
          type: "cards",
          attributes: {},
          relationships: {
            board: {data: {type: "boards", id: user_board.id}}
          }
        }
      }

      expect {
        post "/cards", params: params.to_json, headers: headers
      }.to change { Card.count }.by(1)

      expect(response.status).to eq(201)
      expect(response_body["data"]).to include({
        "type" => "cards",
        "id" => Card.last.id.to_s,
        "attributes" => {"field-values" => {}}
      })
    end

    it "does not create a card on a board not belonging to the user" do
      params = {
        data: {
          type: "cards",
          attributes: {},
          relationships: {
            board: {data: {type: "boards", id: other_user_board.id}}
          }
        }
      }

      expect {
        post "/cards", params: params.to_json, headers: headers
      }.not_to change { Card.count }

      expect(response.status).to eq(422)
      expect(response_body["errors"]).to contain_exactly(
        a_hash_including("detail" => "board - not found")
      )
    end
  end

  describe "PATCH /cards/:id" do
    it "updates a card belonging to the user" do
      params = {
        data: {
          type: "cards",
          id: user_card.id.to_s,
          attributes: {
            "field-values" => {
              user_field.id.to_s => "New Field Value"
            }
          }
        }
      }

      patch "/cards/#{user_card.id}", params: params.to_json, headers: headers

      expect(response.status).to eq(200)
      expect(user_card.reload.field_values[user_field.id.to_s]).to eq("New Field Value")
    end

    it "does not update a card not belonging to the user" do
      params = {
        data: {
          type: "cards",
          id: other_user_card.id.to_s,
          attributes: {
            "field-values" => {
              other_user_field.id.to_s => "New Field Value"
            }
          }
        }
      }

      expect {
        patch "/cards/#{other_user_card.id}", params: params.to_json, headers: headers
      }.not_to change {
        other_user_card.reload.field_values[other_user_field.id.to_s]
      }

      expect(response.status).to eq(404)
    end

    it "does not allow updating the board a card is on" do
      params = {
        data: {
          type: "cards",
          id: user_card.id.to_s,
          relationships: {
            board: {data: {type: "boards", id: other_user_board.id}}
          }
        }
      }

      patch "/cards/#{user_card.id}", params: params.to_json, headers: headers

      expect(response.status).to eq(400)
      expect(user_card.reload.board).to eq(user_board)
    end

    context "when a card-update webhook is defined" do
      let(:webhook_board) {
        FactoryBot.create(:board, user:, board_options: {
          "webhooks" => {
            "card-update": "https://example.com/webhooks/test"
          }
        })
      }
      let!(:webhook_field) {
        FactoryBot.create(:element, :field, board: webhook_board, user:)
      }
      let(:webhook_card) {
        FactoryBot.create(:card, board: webhook_board, user:)
      }

      it "updates the card with the values returned by the webhook" do
        stub_request(:patch, "https://example.com/webhooks/test/#{webhook_card.id}")
          .to_return(body: {
            webhook_field.id.to_s => "Updated Value"
          }.to_json)

        params = {
          data: {
            type: "cards",
            id: webhook_card.id.to_s,
            attributes: {
              "field-values" => {
                webhook_field.id.to_s => "Original Value"
              }
            }
          }
        }

        patch "/cards/#{webhook_card.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(200)
        expect(response_body["data"]["attributes"]["field-values"]).to eq(
          webhook_field.id.to_s => "Updated Value"
        )

        webhook_card.reload
        expect(webhook_card.field_values[webhook_field.id.to_s]).to eql("Updated Value")
      end
    end
  end

  describe "DELETE /cards/:id" do
    it "allows deleting a card belonging to the user" do
      delete "/cards/#{user_card.id}", headers: headers

      expect(response.status).to eq(204)

      expect { Card.find(user_card.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not allow delete a card not belonging to the user" do
      expect {
        delete "/cards/#{other_user_card.id}", headers: headers
      }.not_to change { Card.count }

      expect(response.status).to eq(404)
    end
  end
end
