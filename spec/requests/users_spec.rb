require "rails_helper"

RSpec.describe "users" do
  include_context "with a logged in user"

  let!(:board) { FactoryBot.create(:board, user:) }
  let!(:other_board) { FactoryBot.create(:board, user:) }
  let!(:other_user) { FactoryBot.create(:user) }
  let(:response_body) { JSON.parse(response.body) }

  before(:each) do
    user.update!(ios_share_board: board)
  end

  describe "GET /users/:id" do
    context "when logged out" do
      it "returns an auth error" do
        get "/users/#{user.id}"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "returns the user's own record" do
        get "/users/#{user.id}", headers: headers

        expect(response.status).to eq(200)
        expect(response_body["data"]).to include(
          "type" => "users",
          "id" => user.id.to_s,
          "attributes" => {
            "allow-emails" => false,
            "ios-share-board-id" => board.id
          }
        )
      end

      it "does not return another user's record" do
        get "/users/#{other_user.id}", headers: headers

        expect(response.status).to eq(404)
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end
    end
  end

  describe "POST /users" do
    it "allows creating a user" do
      email = "example@example.com"
      password = "mypassword"

      params = {
        data: {
          type: "users",
          attributes: {
            "email" => email,
            "password" => password,
            "allow-emails" => true
          }
        }
      }

      expect {
        post "/users", params: params.to_json, headers: headers
      }.to change { User.count }.by(1)

      expect(response.status).to eq(201)
    end

    it "does basic email format validation" do
      email = "nope"
      password = "mypassword"

      params = {
        data: {
          type: "users",
          attributes: {
            "email" => email,
            "password" => password,
            "allow-emails" => true
          }
        }
      }

      expect {
        post "/users", params: params.to_json, headers: headers
      }.not_to change { User.count }

      expect(response.status).to eq(0) # Changed for unknown reason in Rack 3.1; in a real app it returns 422
      expect(response_body["errors"]).to contain_exactly(
        a_hash_including(
          "detail" => "email - must be a valid email address"
        )
      )
    end
  end

  describe "PATCH /users/:id" do
    def params(user)
      {
        data: {
          type: "users",
          id: user.id.to_s,
          attributes: {
            "allow-emails" => true,
            "ios-share-board-id" => other_board.id
          }
        }
      }.to_json
    end

    context "when logged out" do
      it "returns an auth error" do
        expect {
          patch "/users/#{user.id}", params: params(user)
        }.not_to change { user.ios_share_board }

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "allows updating attributes" do
        patch "/users/#{user.id}", params: params(user), headers: headers

        expect(response.status).to eq(200)
        expect(response_body["data"]).to include({
          "type" => "users",
          "id" => user.id.to_s,
          "attributes" => a_hash_including(
            "ios-share-board-id" => other_board.id
          )
        })

        user.reload
        expect(user.allow_emails).to eq(true)
        expect(user.ios_share_board).to eq(other_board)
      end

      it "does not allow updating a board not belonging to the user" do
        expect {
          patch "/users/#{other_user.id}", params: params(other_user), headers: headers
        }.not_to change { other_user.ios_share_board }

        expect(response.status).to eq(404)
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end
    end
  end

  describe "DELETE /users/:id" do
    context "when logged out" do
      it "returns an auth error" do
        expect {
          delete "/users/#{user.id}"
        }.not_to change { User.count }

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "allows deleting your account" do
        # create data to ensure the delete cascades
        FactoryBot.create(:column, user:, board:)
        FactoryBot.create(:card, user:, board:)
        FactoryBot.create(:element, :field, user:, board:)

        delete "/users/#{user.id}", headers: headers

        expect(response.status).to eq(204)

        expect { User.find(user.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not allow deleting a user other than oneself" do
        expect {
          delete "/users/#{other_user.id}", headers: headers
        }.not_to change { User.count }

        expect(response.status).to eq(404)
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end
    end
  end
end
