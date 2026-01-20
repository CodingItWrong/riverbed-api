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
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["data"]).to include(
          "type" => "users",
          "id" => user.id.to_s,
          "attributes" => {
            "allow-emails" => false,
            "ios-share-board-id" => board.id
          }
        )
      end

      it "returns complete JSON:API structure with required top-level keys" do
        get "/users/#{user.id}", headers: headers

        expect(response_body).to have_key("data")
        expect(response_body["data"]).to be_a(Hash)
      end

      it "returns user with complete resource object structure" do
        get "/users/#{user.id}", headers: headers

        user_data = response_body["data"]
        expect(user_data).to have_key("type")
        expect(user_data).to have_key("id")
        expect(user_data).to have_key("attributes")
        expect(user_data["type"]).to eq("users")
        expect(user_data["id"]).to be_a(String)
        expect(user_data["attributes"]).to be_a(Hash)
      end

      it "does not return email or password in attributes" do
        get "/users/#{user.id}", headers: headers

        expect(response_body["data"]["attributes"]).not_to have_key("email")
        expect(response_body["data"]["attributes"]).not_to have_key("password")
      end

      it "does not return another user's record" do
        get "/users/#{other_user.id}", headers: headers

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end

      it "returns complete JSON:API error structure for not found" do
        get "/users/#{other_user.id}", headers: headers

        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
        expect(response_body["errors"]).to be_an(Array)

        error = response_body["errors"].first
        expect(error).to have_key("code")
        expect(error).to have_key("title")
        expect(error["code"]).to eq("404")
      end
    end
  end

  describe "POST /users" do
    let(:params) {
      {
        data: {
          type: "users",
          attributes: {
            "email" => "newuser@example.com",
            "password" => "mypassword",
            "allow-emails" => true
          }
        }
      }
    }

    it "allows creating a user without authentication" do
      expect {
        post "/users", params: params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}
      }.to change { User.count }.by(1)

      new_user = User.last
      expect(new_user.email).to eq("newuser@example.com")
      expect(new_user.allow_emails).to eq(true)

      expect(response.status).to eq(201)
      expect(response.content_type).to start_with("application/vnd.api+json")
      expect(response_body["data"]).to include({
        "type" => "users",
        "id" => new_user.id.to_s,
        "attributes" => a_hash_including("allow-emails" => true)
      })
    end

    it "returns complete JSON:API structure for created resource" do
      post "/users", params: params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}

      expect(response_body).to have_key("data")
      expect(response_body["data"]).to be_a(Hash)
      expect(response_body["data"]).to have_key("type")
      expect(response_body["data"]).to have_key("id")
      expect(response_body["data"]).to have_key("attributes")
      expect(response_body["data"]["type"]).to eq("users")
      expect(response_body["data"]["id"]).to be_a(String)
      expect(response_body["data"]["attributes"]).to be_a(Hash)
    end

    it "creates a user with all attributes" do
      params_with_board = {
        data: {
          type: "users",
          attributes: {
            "email" => "test@example.com",
            "password" => "secretpassword",
            "allow-emails" => false,
            "ios-share-board-id" => board.id
          }
        }
      }

      expect {
        post "/users", params: params_with_board.to_json, headers: {"Content-Type" => "application/vnd.api+json"}
      }.to change { User.count }.by(1)

      new_user = User.last
      expect(new_user.email).to eq("test@example.com")
      expect(new_user.authenticate("secretpassword")).to be_truthy
      expect(new_user.allow_emails).to eq(false)
      expect(new_user.ios_share_board_id).to eq(board.id)

      expect(response.status).to eq(201)
      expect(response.content_type).to start_with("application/vnd.api+json")
      expect(response_body["data"]["attributes"]).to include(
        "allow-emails" => false,
        "ios-share-board-id" => board.id
      )
    end

    it "does not return email or password in response" do
      post "/users", params: params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}

      expect(response_body["data"]["attributes"]).not_to have_key("email")
      expect(response_body["data"]["attributes"]).not_to have_key("password")
    end

    it "returns error for invalid JSON syntax" do
      expect {
        post "/users", params: "invalid json{", headers: {"Content-Type" => "application/vnd.api+json"}
      }.not_to change { User.count }

      expect(response.status).to eq(400)
    end

    it "returns error for missing data key" do
      expect {
        post "/users", params: {type: "users"}.to_json, headers: {"Content-Type" => "application/vnd.api+json"}
      }.not_to change { User.count }

      expect(response.status).to eq(400)
      expect(response.content_type).to start_with("application/vnd.api+json")
      expect(response_body).to have_key("errors")
    end

    it "returns error for missing type in data" do
      expect {
        post "/users", params: {data: {attributes: {}}}.to_json, headers: {"Content-Type" => "application/vnd.api+json"}
      }.not_to change { User.count }

      expect(response.status).to eq(400)
      expect(response.content_type).to start_with("application/vnd.api+json")
      expect(response_body).to have_key("errors")
    end

    it "returns error for wrong type in data" do
      expect {
        post "/users", params: {data: {type: "boards", attributes: {}}}.to_json, headers: {"Content-Type" => "application/vnd.api+json"}
      }.not_to change { User.count }

      expect(response.status).to eq(400)
      expect(response.content_type).to start_with("application/vnd.api+json")
      expect(response_body).to have_key("errors")
    end

    it "returns error for invalid email format" do
      invalid_params = {
        data: {
          type: "users",
          attributes: {
            "email" => "invalid-email",
            "password" => "mypassword",
            "allow-emails" => true
          }
        }
      }

      expect {
        post "/users", params: invalid_params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}
      }.not_to change { User.count }

      expect(response.status).to eq(422)
      expect(response.content_type).to start_with("application/vnd.api+json")
      expect(response_body["errors"]).to include(
        a_hash_including(
          "code" => "422",
          "detail" => a_string_including("email")
        )
      )
    end

    it "returns error for duplicate email" do
      existing_user = FactoryBot.create(:user, email: "duplicate@example.com")
      duplicate_params = {
        data: {
          type: "users",
          attributes: {
            "email" => "duplicate@example.com",
            "password" => "mypassword",
            "allow-emails" => true
          }
        }
      }

      expect {
        post "/users", params: duplicate_params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}
      }.not_to change { User.count }

      expect(response.status).to eq(422)
      expect(response.content_type).to start_with("application/vnd.api+json")
      expect(response_body["errors"]).to include(
        a_hash_including(
          "code" => "422",
          "detail" => a_string_including("email")
        )
      )
    end
  end

  describe "PATCH /users/:id" do
    def params(user, attributes)
      {
        data: {
          type: "users",
          id: user.id.to_s,
          attributes: attributes
        }
      }.to_json
    end

    context "when logged out" do
      it "returns an auth error" do
        expect {
          patch "/users/#{user.id}", params: params(user, {"allow-emails" => true})
        }.not_to change { user.reload.allow_emails }

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "allows updating attributes" do
        patch "/users/#{user.id}", params: params(user, {
          "allow-emails" => true,
          "ios-share-board-id" => other_board.id
        }), headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["data"]).to include({
          "type" => "users",
          "id" => user.id.to_s,
          "attributes" => a_hash_including(
            "allow-emails" => true,
            "ios-share-board-id" => other_board.id
          )
        })

        user.reload
        expect(user.allow_emails).to eq(true)
        expect(user.ios_share_board).to eq(other_board)
      end

      it "returns complete JSON:API structure for updated resource" do
        patch "/users/#{user.id}", params: params(user, {"allow-emails" => true}), headers: headers

        expect(response_body).to have_key("data")
        expect(response_body["data"]).to be_a(Hash)
        expect(response_body["data"]).to have_key("type")
        expect(response_body["data"]).to have_key("id")
        expect(response_body["data"]).to have_key("attributes")
        expect(response_body["data"]["type"]).to eq("users")
        expect(response_body["data"]["id"]).to eq(user.id.to_s)
        expect(response_body["data"]["attributes"]).to be_a(Hash)
      end

      it "allows updating password" do
        patch "/users/#{user.id}", params: params(user, {"password" => "newpassword"}), headers: headers

        expect(response.status).to eq(200)
        user.reload
        expect(user.authenticate("newpassword")).to be_truthy
        expect(user.authenticate("password")).to be_falsey
      end

      it "does not allow updating another user's record" do
        expect {
          patch "/users/#{other_user.id}", params: params(other_user, {"allow-emails" => true}), headers: headers
        }.not_to change { other_user.reload.allow_emails }

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end

      it "returns error for invalid JSON syntax" do
        expect {
          patch "/users/#{user.id}", params: "invalid json{", headers: headers
        }.not_to change { user.reload.allow_emails }

        expect(response.status).to eq(400)
      end

      it "returns error for missing data key" do
        expect {
          patch "/users/#{user.id}", params: {type: "users"}.to_json, headers: headers
        }.not_to change { user.reload.allow_emails }

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for id mismatch" do
        expect {
          patch "/users/#{user.id}",
            params: {
              data: {
                type: "users",
                id: "999999",
                attributes: {"allow-emails" => true}
              }
            }.to_json,
            headers: headers
        }.not_to change { user.reload.allow_emails }

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for wrong type in data" do
        expect {
          patch "/users/#{user.id}",
            params: {
              data: {
                type: "boards",
                id: user.id.to_s,
                attributes: {"allow-emails" => true}
              }
            }.to_json,
            headers: headers
        }.not_to change { user.reload.allow_emails }

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "does not return email or password in response" do
        patch "/users/#{user.id}", params: params(user, {"allow-emails" => true}), headers: headers

        expect(response_body["data"]["attributes"]).not_to have_key("email")
        expect(response_body["data"]["attributes"]).not_to have_key("password")
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
        expect(response.body).to be_empty

        expect { User.find(user.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not allow deleting another user's account" do
        expect {
          delete "/users/#{other_user.id}", headers: headers
        }.not_to change { User.count }

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end
    end
  end
end
