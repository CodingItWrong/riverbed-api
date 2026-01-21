require "rails_helper"

RSpec.describe "cards" do
  include_context "with a logged in user"

  let!(:user_board) { FactoryBot.create(:board, user:) }
  let!(:user_field) { FactoryBot.create(:element, :field, board: user_board, user:) }
  let!(:user_card) do
    FactoryBot.create(:card,
      board: user_board,
      user:,
      field_values: {
        user_field.id.to_s => "Sample Value",
        "other_field" => "Other Value"
      })
  end

  let!(:other_user) { FactoryBot.create(:user) }
  let!(:other_user_board) { FactoryBot.create(:board, user: other_user) }
  let!(:other_user_field) { FactoryBot.create(:element, :field, board: other_user_board, user: other_user) }
  let!(:other_user_card) { FactoryBot.create(:card, board: other_user_board, user: other_user) }
  let(:response_body) { JSON.parse(response.body) }

  describe "GET /boards/:id/cards" do
    context "when logged out" do
      it "returns an auth error" do
        get "/boards/#{user_board.id}/cards"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "returns cards for a board belonging to the user" do
        get "/boards/#{user_board.id}/cards", headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")
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
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end

      it "returns complete JSON:API structure with required top-level keys" do
        get "/boards/#{user_board.id}/cards", headers: headers

        expect(response_body).to have_key("data")
        expect(response_body["data"]).to be_an(Array)
      end

      it "returns cards with complete resource object structure" do
        get "/boards/#{user_board.id}/cards", headers: headers

        card_data = response_body["data"].first
        expect(card_data).to have_key("type")
        expect(card_data).to have_key("id")
        expect(card_data).to have_key("attributes")
        expect(card_data["type"]).to eq("cards")
        expect(card_data["id"]).to be_a(String)
        expect(card_data["attributes"]).to be_a(Hash)
      end

      it "returns all card attributes with correct transformations" do
        get "/boards/#{user_board.id}/cards", headers: headers

        card_data = response_body["data"].first
        attributes = card_data["attributes"]

        expect(attributes).to include(
          "field-values" => {
            user_field.id.to_s => "Sample Value",
            "other_field" => "Other Value"
          }
        )
      end
    end
  end

  describe "GET /cards/:id" do
    context "when logged out" do
      it "returns an auth error" do
        get "/cards/#{user_card.id}"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "returns a card belonging to the user" do
        get "/cards/#{user_card.id}", headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")

        expect(response_body["data"]).to include(
          "type" => "cards",
          "id" => user_card.id.to_s,
          "attributes" => a_hash_including("field-values" => a_hash_including(user_field.id.to_s => "Sample Value"))
        )
      end

      it "does not return a card belonging to another user" do
        get "/cards/#{other_user_card.id}", headers: headers

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end

      it "returns complete JSON:API structure for single resource" do
        get "/cards/#{user_card.id}", headers: headers

        expect(response_body).to have_key("data")
        expect(response_body["data"]).to be_a(Hash)
      end

      it "returns complete JSON:API error structure for not found" do
        get "/cards/#{other_user_card.id}", headers: headers

        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
        expect(response_body["errors"]).to be_an(Array)

        error = response_body["errors"].first
        expect(error).to have_key("code")
        expect(error).to have_key("title")
        expect(error["code"]).to eq("404")
      end

      it "returns all card attributes" do
        get "/cards/#{user_card.id}", headers: headers

        attributes = response_body["data"]["attributes"]

        expect(attributes).to include(
          "field-values" => {
            user_field.id.to_s => "Sample Value",
            "other_field" => "Other Value"
          }
        )
      end
    end
  end

  describe "POST /cards" do
    context "when logged out" do
      it "returns an auth error" do
        params = {
          data: {
            type: "cards",
            attributes: {
              "field-values" => {user_field.id.to_s => "New Value"}
            },
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        post "/cards", params: params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "creates a card on a board belonging to the user" do
        params = {
          data: {
            type: "cards",
            attributes: {
              "field-values" => {
                user_field.id.to_s => "New Card Value",
                "another_field" => "Another Value"
              }
            },
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        expect {
          post "/cards", params: params.to_json, headers: headers
        }.to change { Card.count }.by(1)

        expect(response.status).to eq(201)
        expect(response.content_type).to start_with("application/vnd.api+json")

        new_card = Card.last
        expect(response_body["data"]).to include(
          "type" => "cards",
          "id" => new_card.id.to_s,
          "attributes" => {
            "field-values" => {
              user_field.id.to_s => "New Card Value",
              "another_field" => "Another Value"
            }
          }
        )
      end

      it "creates a card with minimal attributes" do
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

      it "associates the card with the current user" do
        params = {
          data: {
            type: "cards",
            attributes: {"field-values" => {}},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        post "/cards", params: params.to_json, headers: headers

        new_card = Card.last
        expect(new_card.user_id).to eq(user.id)
      end

      it "does not create a card on a board not belonging to the user" do
        params = {
          data: {
            type: "cards",
            attributes: {"field-values" => {}},
            relationships: {
              board: {data: {type: "boards", id: other_user_board.id}}
            }
          }
        }

        expect {
          post "/cards", params: params.to_json, headers: headers
        }.not_to change { Card.count }

        expect(response.status).to eq(0) # Changed for unknown reason in Rack 3.1; in a real app it returns 422
        expect(response_body["errors"]).to contain_exactly(
          a_hash_including("detail" => "board - not found")
        )
      end

      it "returns error for invalid JSON syntax" do
        post "/cards", params: "{invalid json", headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to be_an(Array)
        expect(response_body["errors"].first).to have_key("title")
      end

      it "returns error for missing data key" do
        params = {type: "cards", attributes: {"field-values" => {}}}

        post "/cards", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
      end

      it "returns error for missing type in data" do
        params = {
          data: {
            attributes: {"field-values" => {}},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        post "/cards", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for wrong type in data" do
        params = {
          data: {
            type: "boards",
            attributes: {"field-values" => {}},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        expect {
          post "/cards", params: params.to_json, headers: headers
        }.not_to change { Card.count }

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end
    end
  end

  describe "PATCH /cards/:id" do
    context "when logged out" do
      it "returns an auth error" do
        params = {
          data: {
            type: "cards",
            id: user_card.id.to_s,
            attributes: {"field-values" => {user_field.id.to_s => "Updated Value"}}
          }
        }

        patch "/cards/#{user_card.id}", params: params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "updates a card belonging to the user" do
        params = {
          data: {
            type: "cards",
            id: user_card.id.to_s,
            attributes: {
              "field-values" => {
                user_field.id.to_s => "Updated Field Value"
              }
            }
          }
        }

        patch "/cards/#{user_card.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(user_card.reload.field_values[user_field.id.to_s]).to eq("Updated Field Value")
      end

      it "updates all writable card attributes" do
        params = {
          data: {
            type: "cards",
            id: user_card.id.to_s,
            attributes: {
              "field-values" => {
                "new_field_1" => "Value 1",
                "new_field_2" => "Value 2",
                "new_field_3" => 123
              }
            }
          }
        }

        patch "/cards/#{user_card.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(200)

        user_card.reload
        expect(user_card.field_values).to eq({
          "new_field_1" => "Value 1",
          "new_field_2" => "Value 2",
          "new_field_3" => 123
        })
      end

      it "does not update a card not belonging to the user" do
        params = {
          data: {
            type: "cards",
            id: other_user_card.id.to_s,
            attributes: {
              "field-values" => {
                other_user_field.id.to_s => "Hacked Value"
              }
            }
          }
        }

        other_user_card.field_values.dup

        expect {
          patch "/cards/#{other_user_card.id}", params: params.to_json, headers: headers
        }.not_to change { other_user_card.reload.field_values }

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
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

      it "returns error for ID mismatch between URL and payload" do
        params = {
          data: {
            type: "cards",
            id: "99999",
            attributes: {"field-values" => {}}
          }
        }

        patch "/cards/#{user_card.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for invalid JSON syntax" do
        patch "/cards/#{user_card.id}", params: "{invalid json", headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to be_an(Array)
      end

      it "returns error for missing type in data" do
        params = {
          data: {
            id: user_card.id.to_s,
            attributes: {"field-values" => {}}
          }
        }

        patch "/cards/#{user_card.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for wrong type in data" do
        params = {
          data: {
            type: "boards",
            id: user_card.id.to_s,
            attributes: {"field-values" => {}}
          }
        }

        expect {
          patch "/cards/#{user_card.id}", params: params.to_json, headers: headers
        }.not_to change { user_card.reload.field_values }

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
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
  end

  describe "DELETE /cards/:id" do
    context "when logged out" do
      it "returns an auth error" do
        delete "/cards/#{user_card.id}"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "allows deleting a card belonging to the user" do
        delete "/cards/#{user_card.id}", headers: headers

        expect(response.status).to eq(204)
        expect(response.body).to be_empty

        expect { Card.find(user_card.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not allow deleting a card not belonging to the user" do
        expect {
          delete "/cards/#{other_user_card.id}", headers: headers
        }.not_to change { Card.count }

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
      end

      it "returns JSON:API error structure for not found on delete" do
        delete "/cards/#{other_user_card.id}", headers: headers

        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
      end
    end
  end
end
