require "rails_helper"

RSpec.describe "boards" do
  include_context "with a logged in user"

  let!(:user_board) { FactoryBot.create(:board, user:) }
  let!(:other_user_board) { FactoryBot.create(:board) }
  let(:response_body) { JSON.parse(response.body) }

  describe "GET /boards" do
    context "when logged out" do
      it "returns an auth error" do
        get "/boards"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "returns the user's board" do
        get "/boards", headers: headers

        expect(response.status).to eq(200)
        expect(response_body["data"]).to contain_exactly(a_hash_including(
          "type" => "boards",
          "id" => user_board.id.to_s,
          "attributes" => a_hash_including("name" => user_board.name)
        ))
      end
    end
  end

  describe "GET /boards/:id" do
    context "when logged out" do
      it "returns an auth error" do
        get "/boards/#{user_board.id}"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "returns a board belonging to the user" do
        get("/boards/#{user_board.id}", headers: headers)

        expect(response.status).to eq(200)

        expect(response_body["data"]).to include(
          "type" => "boards",
          "id" => user_board.id.to_s,
          "attributes" => a_hash_including("name" => user_board.name)
        )
      end

      it "does not return a board belonging to another user" do
        get("/boards/#{other_user_board.id}", headers: headers)

        expect(response.status).to eq(404)
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end
    end
  end

  describe "POST /boards" do
    let(:params) {
      {
        data: {
          type: "boards",
          attributes: {}
        }
      }
    }

    context "when logged out" do
      it "returns an auth error" do
        expect {
          post "/boards", params: params.to_json
        }.not_to change { Board.count }

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "creates a board, column, and card" do
        expect {
          post "/boards", params: params.to_json, headers: headers
        }.to change { Board.count }.by(1)

        board = Board.last
        expect(board.user).to eq(user)
        expect(board.columns.map { _1.name }).to eq(["All Cards"])
        expect(board.cards.count).to eq(1)

        expect(response.status).to eq(201)
        expect(response_body["data"]).to include({
          "type" => "boards",
          "id" => board.id.to_s,
          "attributes" => a_hash_including("name" => nil)
        })
      end
    end
  end

  describe "PATCH /boards/:id" do
    let(:name) { "Updated Board Name" }

    def params(board)
      {
        data: {
          type: "boards",
          id: board.id.to_s,
          attributes: {name:}
        }
      }.to_json
    end

    context "when logged out" do
      it "returns an auth error" do
        expect {
          patch "/boards/#{user_board.id}", params: params(user_board)
        }.not_to change { user_board.name }

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "allows updating a board belonging to the user" do
        patch "/boards/#{user_board.id}", params: params(user_board), headers: headers

        expect(response.status).to eq(200)
        expect(response_body["data"]).to include({
          "type" => "boards",
          "id" => user_board.id.to_s,
          "attributes" => a_hash_including("name" => name)
        })

        expect(user_board.reload.name).to eq(name)
      end

      it "does not allow updating a board not belonging to the user" do
        expect {
          patch "/boards/#{other_user_board.id}", params: params(other_user_board), headers: headers
        }.not_to change { other_user_board.name }

        expect(response.status).to eq(404)
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end
    end
  end

  describe "DELETE /boards/:id" do
    context "when logged out" do
      it "returns an auth error" do
        expect {
          delete "/boards/#{user_board.id}"
        }.not_to change { Board.count }

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "allows deleting a board belonging to the user" do
        delete "/boards/#{user_board.id}", headers: headers

        expect(response.status).to eq(204)
        expect(response.body).to be_empty

        expect { Board.find(user_board.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not allow deleting a board not belonging to the user" do
        expect {
          delete "/boards/#{other_user_board.id}", headers: headers
        }.not_to change { Board.count }

        expect(response.status).to eq(404)
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end
    end
  end
end
