require "rails_helper"

RSpec.describe "columns" do
  include_context "with a logged in user"

  let!(:user_board) { FactoryBot.create(:board, user:) }
  let!(:user_column) { FactoryBot.create(:column, board: user_board, user:) }

  let!(:other_user_board) { FactoryBot.create(:board) }
  let!(:other_user_column) { FactoryBot.create(:column, board: other_user_board) }
  let(:response_body) { JSON.parse(response.body) }

  describe "GET /boards/:id/columns" do
    it "returns columns for a board belonging to the user" do
      get "/boards/#{user_board.id}/columns", headers: headers

      expect(response.status).to eq(200)
      expect(response_body["data"]).to contain_exactly(
        a_hash_including(
          "type" => "columns",
          "id" => user_column.id.to_s
        )
      )
    end

    it "does not return columns for a board belonging to another user" do
      get "/boards/#{other_user_board.id}/columns", headers: headers

      expect(response.status).to eq(404)
    end
  end

  describe "POST /columns" do
    it "creates a column on a board belonging to the user" do
      params = {
        data: {
          type: "columns",
          attributes: {},
          relationships: {
            board: {data: {type: "boards", id: user_board.id}}
          }
        }
      }

      expect {
        post "/columns", params: params.to_json, headers: headers
      }.to change { Column.count }.by(1)

      expect(response.status).to eq(201)
      expect(response_body["data"]).to include({
        "type" => "columns",
        "id" => Column.last.id.to_s,
        "attributes" => a_hash_including("name" => nil)
      })
    end

    it "does not create a column on a board not belonging to the user"
  end

  describe "PATCH /columns/:id" do
    it "updates a column belonging to the user" do
      params = {
        data: {
          type: "columns",
          id: user_column.id.to_s,
          attributes: {"name" => "New Name"}
        }
      }

      patch "/columns/#{user_column.id}", params: params.to_json, headers: headers

      expect(response.status).to eq(200)
      expect(user_column.reload.name).to eq("New Name")
    end

    it "does not update a columm not belonging to the user" do
      params = {
        data: {
          type: "columns",
          id: other_user_column.id.to_s,
          attributes: {"name" => "New Name"}
        }
      }

      expect {
        patch "/columns/#{other_user_column.id}", params: params.to_json, headers: headers
      }.not_to change { other_user_column.reload.name }

      expect(response.status).to eq(404)
    end

    it "does not allow updating the board a column is on" do
      params = {
        data: {
          type: "columns",
          id: user_column.id.to_s,
          relationships: {
            board: {data: {type: "boards", id: other_user_board.id}}
          }
        }
      }

      patch "/columns/#{user_column.id}", params: params.to_json, headers: headers

      expect(response.status).to eq(400)
      expect(user_column.reload.board).to eq(user_board)
    end
  end

  describe "DELETE /columns/:id" do
    it "allows deleting a column belonging to the user" do
      delete "/columns/#{user_column.id}", headers: headers

      expect(response.status).to eq(204)

      expect { Column.find(user_column.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not allow delete a column not belonging to the user" do
      expect {
        delete "/columns/#{other_user_column.id}", headers: headers
      }.not_to change { Column.count }

      expect(response.status).to eq(404)
    end
  end
end
