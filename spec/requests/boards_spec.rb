require "rails_helper"

RSpec.describe "boards" do
  let!(:board) { FactoryBot.create(:board) }

  describe "GET /boards" do
    context "when logged out" do
      it "returns an auth error" do
        get "/boards"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      include_context "with a logged in user"

      it "returns the board" do
        get "/boards", headers: headers

        expect(response.status).to eq(200)

        response_body = JSON.parse(response.body)
        expect(response_body["data"]).to contain_exactly(a_hash_including(
          "type" => "boards",
          "id" => board.id.to_s,
          "attributes" => a_hash_including("name" => board.name)
        ))
      end
    end
  end

  describe "GET /boards/:id" do
    context "when logged out" do
      it "returns an auth error" do
        get "/boards/#{board.id}"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      include_context "with a logged in user"

      it "returns the board" do
        get("/boards/#{board.id}", headers: headers)

        expect(response.status).to eq(200)

        response_body = JSON.parse(response.body)
        expect(response_body["data"]).to include(
          "type" => "boards",
          "id" => board.id.to_s,
          "attributes" => a_hash_including("name" => board.name)
        )
      end
    end
  end
end
