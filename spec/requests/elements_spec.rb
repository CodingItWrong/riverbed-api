require "rails_helper"

RSpec.describe "elements" do
  include_context "with a logged in user"

  let!(:user_board) { FactoryBot.create(:board, user:) }
  let!(:user_element) { FactoryBot.create(:element, :field, board: user_board, user:) }

  let!(:other_user) { FactoryBot.create(:user) }
  let!(:other_user_board) { FactoryBot.create(:board, user: other_user) }
  let!(:other_user_element) { FactoryBot.create(:element, :field, board: other_user_board, user: other_user) }
  let(:response_body) { JSON.parse(response.body) }

  describe "GET /boards/:id/elements" do
    it "returns elements for a board belonging to the user" do
      get "/boards/#{user_board.id}/elements", headers: headers

      expect(response.status).to eq(200)
      expect(response_body["data"]).to contain_exactly(
        a_hash_including(
          "type" => "elements",
          "id" => user_element.id.to_s
        )
      )
    end

    it "does not return columns for a board belonging to another user" do
      get "/boards/#{other_user_board.id}/elements", headers: headers

      expect(response.status).to eq(404)
    end
  end

  describe "GET /elements/:id" do
    it "returns an element for a board belonging to the user" do
      get "/elements/#{user_element.id}", headers: headers

      expect(response.status).to eq(200)
      expect(response_body["data"]).to include(
        "type" => "elements",
        "id" => user_element.id.to_s
      )
    end

    it "does not return columns for a board belonging to another user" do
      get "/elements/#{other_user_element.id}", headers: headers

      expect(response.status).to eq(404)
    end
  end

  describe "POST /elements" do
    it "creates an element on a board belonging to the user" do
      params = {
        data: {
          type: "elements",
          attributes: {
            "element-type" => "field"
          },
          relationships: {
            board: {data: {type: "boards", id: user_board.id}}
          }
        }
      }

      expect {
        post "/elements", params: params.to_json, headers: headers
      }.to change { Element.count }.by(1)

      expect(response.status).to eq(201)
      expect(response_body["data"]).to include({
        "type" => "elements",
        "id" => Element.last.id.to_s,
        "attributes" => a_hash_including(
          "element-type" => "field"
        )
      })
    end

    it "does not create an element on a board not belonging to the user" do
      params = {
        data: {
          type: "elements",
          attributes: {"element-type" => "field"},
          relationships: {
            board: {data: {type: "boards", id: other_user_board.id}}
          }
        }
      }

      expect {
        post "/elements", params: params.to_json, headers: headers
      }.not_to change { Element.count }

      expect(response.status).to eq(422)
      expect(response_body["errors"]).to contain_exactly(
        a_hash_including("detail" => "board - not found")
      )
    end
  end

  describe "PATCH /elements/:id" do
    it "updates an element belonging to the user" do
      params = {
        data: {
          type: "elements",
          id: user_element.id.to_s,
          attributes: {"name" => "New Name"}
        }
      }

      patch "/elements/#{user_element.id}", params: params.to_json, headers: headers

      expect(response.status).to eq(200)
      expect(user_element.reload.name).to eq("New Name")
    end

    it "does not update a columm not belonging to the user" do
      params = {
        data: {
          type: "elements",
          id: other_user_element.id.to_s,
          attributes: {"name" => "New Name"}
        }
      }

      expect {
        patch "/elements/#{other_user_element.id}", params: params.to_json, headers: headers
      }.not_to change { other_user_element.reload.name }

      expect(response.status).to eq(404)
    end

    it "does not allow updating the board an element is on" do
      params = {
        data: {
          type: "elements",
          id: user_element.id.to_s,
          relationships: {
            board: {data: {type: "boards", id: other_user_board.id}}
          }
        }
      }

      patch "/elements/#{user_element.id}", params: params.to_json, headers: headers

      expect(response.status).to eq(400)
      expect(user_element.reload.board).to eq(user_board)
    end
  end

  describe "DELETE /elements/:id" do
    it "allows deleting an element belonging to the user" do
      delete "/elements/#{user_element.id}", headers: headers

      expect(response.status).to eq(204)

      expect { Element.find(user_element.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not allow deleting an element not belonging to the user" do
      expect {
        delete "/elements/#{other_user_element.id}", headers: headers
      }.not_to change { Element.count }

      expect(response.status).to eq(404)
    end

    it "deletes values for the field from cards", :aggregate_failures do
      other_element = FactoryBot.create(:element, :field, user:, board: user_board)
      card1 = FactoryBot.create(:card, user:, board: user_board, field_values: {user_element.id.to_s => "field value", other_element.id.to_s => "other field value"})
      card2 = FactoryBot.create(:card, user:, board: user_board, field_values: {user_element.id.to_s => "field value", other_element.id.to_s => "other field value"})

      delete "/elements/#{user_element.id}", headers: headers

      card1.reload
      expect(card1.field_values).to have_key(other_element.id.to_s)
      expect(card1.field_values).not_to have_key(user_element.id.to_s)

      card2.reload
      expect(card2.field_values).to have_key(other_element.id.to_s)
      expect(card2.field_values).not_to have_key(user_element.id.to_s)
    end
  end
end
