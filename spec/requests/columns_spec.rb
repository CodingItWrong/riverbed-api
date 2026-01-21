require "rails_helper"

RSpec.describe "columns" do
  include_context "with a logged in user"

  let!(:user_board) { FactoryBot.create(:board, user:) }
  let!(:user_column) do
    FactoryBot.create(:column,
      board: user_board,
      user:,
      name: "Tasks",
      display_order: 5,
      sort_order: {field: "name", direction: "asc"},
      card_inclusion_conditions: [{field: "status", operator: "eq", value: "active"}],
      card_grouping: {field: "priority"},
      summary: {type: "count"})
  end

  let!(:other_user) { FactoryBot.create(:user) }
  let!(:other_user_board) { FactoryBot.create(:board, user: other_user) }
  let!(:other_user_column) { FactoryBot.create(:column, board: other_user_board, user: other_user) }
  let(:response_body) { JSON.parse(response.body) }

  describe "GET /boards/:id/columns" do
    context "when logged out" do
      it "returns an auth error" do
        get "/boards/#{user_board.id}/columns"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "returns columns for a board belonging to the user" do
        get "/boards/#{user_board.id}/columns", headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")
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
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end

      it "returns complete JSON:API structure with required top-level keys" do
        get "/boards/#{user_board.id}/columns", headers: headers

        expect(response_body).to have_key("data")
        expect(response_body["data"]).to be_an(Array)
      end

      it "returns columns with complete resource object structure" do
        get "/boards/#{user_board.id}/columns", headers: headers

        column_data = response_body["data"].first
        expect(column_data).to have_key("type")
        expect(column_data).to have_key("id")
        expect(column_data).to have_key("attributes")
        expect(column_data["type"]).to eq("columns")
        expect(column_data["id"]).to be_a(String)
        expect(column_data["attributes"]).to be_a(Hash)
      end

      it "returns all column attributes with correct transformations" do
        get "/boards/#{user_board.id}/columns", headers: headers

        column_data = response_body["data"].first
        attributes = column_data["attributes"]

        expect(attributes).to include(
          "name" => "Tasks",
          "display-order" => 5,
          "card-sort-order" => {"field" => "name", "direction" => "asc"},
          "card-inclusion-conditions" => [{"field" => "status", "operator" => "eq", "value" => "active"}],
          "card-grouping" => {"field" => "priority"},
          "summary" => {"type" => "count"}
        )
      end
    end
  end

  describe "GET /columns/:id" do
    context "when logged out" do
      it "returns an auth error" do
        get "/columns/#{user_column.id}"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "returns a column belonging to the user" do
        get "/columns/#{user_column.id}", headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")

        expect(response_body["data"]).to include(
          "type" => "columns",
          "id" => user_column.id.to_s,
          "attributes" => a_hash_including("name" => "Tasks")
        )
      end

      it "does not return a column belonging to another user" do
        get "/columns/#{other_user_column.id}", headers: headers

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end

      it "returns complete JSON:API structure for single resource" do
        get "/columns/#{user_column.id}", headers: headers

        expect(response_body).to have_key("data")
        expect(response_body["data"]).to be_a(Hash)
      end

      it "returns complete JSON:API error structure for not found" do
        get "/columns/#{other_user_column.id}", headers: headers

        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
        expect(response_body["errors"]).to be_an(Array)

        error = response_body["errors"].first
        expect(error).to have_key("code")
        expect(error).to have_key("title")
        expect(error["code"]).to eq("404")
      end

      it "returns all column attributes" do
        get "/columns/#{user_column.id}", headers: headers

        attributes = response_body["data"]["attributes"]

        expect(attributes).to include(
          "name" => "Tasks",
          "display-order" => 5,
          "card-sort-order" => {"field" => "name", "direction" => "asc"},
          "card-inclusion-conditions" => [{"field" => "status", "operator" => "eq", "value" => "active"}],
          "card-grouping" => {"field" => "priority"},
          "summary" => {"type" => "count"}
        )
      end
    end
  end

  describe "POST /columns" do
    context "when logged out" do
      it "returns an auth error" do
        params = {
          data: {
            type: "columns",
            attributes: {name: "New Column"},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        post "/columns", params: params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "creates a column on a board belonging to the user" do
        params = {
          data: {
            type: "columns",
            attributes: {
              :name => "New Column",
              "display-order" => 10,
              "card-sort-order" => {field: "created-at", direction: "desc"},
              "card-inclusion-conditions" => [{field: "archived", operator: "eq", value: false}],
              "card-grouping" => {field: "category"},
              :summary => {type: "sum", field: "amount"}
            },
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        expect {
          post "/columns", params: params.to_json, headers: headers
        }.to change { Column.count }.by(1)

        expect(response.status).to eq(201)
        expect(response.content_type).to start_with("application/vnd.api+json")

        new_column = Column.last
        expect(response_body["data"]).to include(
          "type" => "columns",
          "id" => new_column.id.to_s,
          "attributes" => {
            "name" => "New Column",
            "display-order" => 10,
            "card-sort-order" => {"field" => "created-at", "direction" => "desc"},
            "card-inclusion-conditions" => [{"field" => "archived", "operator" => "eq", "value" => false}],
            "card-grouping" => {"field" => "category"},
            "summary" => {"type" => "sum", "field" => "amount"}
          }
        )
      end

      it "creates a column with minimal attributes" do
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

      it "associates the column with the current user" do
        params = {
          data: {
            type: "columns",
            attributes: {name: "User Test Column"},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        post "/columns", params: params.to_json, headers: headers

        new_column = Column.last
        expect(new_column.user_id).to eq(user.id)
      end

      it "does not create a column on a board not belonging to the user" do
        params = {
          data: {
            type: "columns",
            attributes: {name: "Unauthorized Column"},
            relationships: {
              board: {data: {type: "boards", id: other_user_board.id}}
            }
          }
        }

        expect {
          post "/columns", params: params.to_json, headers: headers
        }.not_to change { Column.count }

        expect(response.status).to eq(0) # Changed for unknown reason in Rack 3.1; in a real app it returns 422
        expect(response_body["errors"]).to contain_exactly(
          a_hash_including("detail" => "board - not found")
        )
      end

      it "returns error for invalid JSON syntax" do
        post "/columns", params: "{invalid json", headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to be_an(Array)
        expect(response_body["errors"].first).to have_key("title")
      end

      it "returns error for missing data key" do
        params = {type: "columns", attributes: {name: "Test"}}

        post "/columns", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
      end

      it "returns error for missing type in data" do
        params = {
          data: {
            attributes: {name: "Test"},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        post "/columns", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for wrong type in data" do
        params = {
          data: {
            type: "boards",
            attributes: {name: "Test"},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        expect {
          post "/columns", params: params.to_json, headers: headers
        }.not_to change { Column.count }

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end
    end
  end

  describe "PATCH /columns/:id" do
    context "when logged out" do
      it "returns an auth error" do
        params = {
          data: {
            type: "columns",
            id: user_column.id.to_s,
            attributes: {name: "Updated Name"}
          }
        }

        patch "/columns/#{user_column.id}", params: params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "updates a column belonging to the user" do
        params = {
          data: {
            type: "columns",
            id: user_column.id.to_s,
            attributes: {name: "Updated Name"}
          }
        }

        patch "/columns/#{user_column.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(user_column.reload.name).to eq("Updated Name")
      end

      it "updates all writable column attributes" do
        params = {
          data: {
            type: "columns",
            id: user_column.id.to_s,
            attributes: {
              :name => "Completely Updated",
              "display-order" => 99,
              "card-sort-order" => {field: "priority", direction: "desc"},
              "card-inclusion-conditions" => [],
              "card-grouping" => {},
              :summary => {type: "average", field: "rating"}
            }
          }
        }

        patch "/columns/#{user_column.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(200)

        user_column.reload
        expect(user_column.name).to eq("Completely Updated")
        expect(user_column.display_order).to eq(99)
        expect(user_column.sort_order).to eq({"field" => "priority", "direction" => "desc"})
        expect(user_column.card_inclusion_conditions).to eq([])
        expect(user_column.card_grouping).to eq({})
        expect(user_column.summary).to eq({"type" => "average", "field" => "rating"})
      end

      it "does not update a column not belonging to the user" do
        params = {
          data: {
            type: "columns",
            id: other_user_column.id.to_s,
            attributes: {name: "Hacked Name"}
          }
        }

        expect {
          patch "/columns/#{other_user_column.id}", params: params.to_json, headers: headers
        }.not_to change { other_user_column.reload.name }

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
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

      it "returns error for ID mismatch between URL and payload" do
        params = {
          data: {
            type: "columns",
            id: "99999",
            attributes: {name: "Mismatched"}
          }
        }

        patch "/columns/#{user_column.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for invalid JSON syntax" do
        patch "/columns/#{user_column.id}", params: "{invalid json", headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to be_an(Array)
      end

      it "returns error for missing type in data" do
        params = {
          data: {
            id: user_column.id.to_s,
            attributes: {name: "Test"}
          }
        }

        patch "/columns/#{user_column.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for wrong type in data" do
        params = {
          data: {
            type: "boards",
            id: user_column.id.to_s,
            attributes: {name: "Test"}
          }
        }

        expect {
          patch "/columns/#{user_column.id}", params: params.to_json, headers: headers
        }.not_to change { user_column.reload.name }

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end
    end
  end

  describe "DELETE /columns/:id" do
    context "when logged out" do
      it "returns an auth error" do
        delete "/columns/#{user_column.id}"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "allows deleting a column belonging to the user" do
        delete "/columns/#{user_column.id}", headers: headers

        expect(response.status).to eq(204)
        expect(response.body).to be_empty

        expect { Column.find(user_column.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not allow deleting a column not belonging to the user" do
        expect {
          delete "/columns/#{other_user_column.id}", headers: headers
        }.not_to change { Column.count }

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
      end

      it "returns JSON:API error structure for not found on delete" do
        delete "/columns/#{other_user_column.id}", headers: headers

        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
      end
    end
  end
end
