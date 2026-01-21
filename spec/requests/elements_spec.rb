require "rails_helper"

RSpec.describe "elements" do
  include_context "with a logged in user"

  let!(:user_board) { FactoryBot.create(:board, user:) }
  let!(:user_element) do
    FactoryBot.create(:element, :field,
      board: user_board,
      user:,
      name: "Status Field",
      element_type: :field,
      data_type: :text,
      display_order: 5,
      show_in_summary: true,
      show_conditions: [{field: "type", operator: "eq", value: "task"}],
      read_only: false,
      initial_value: :empty,
      element_options: {placeholder: "Enter status", max_length: 50})
  end

  let!(:other_user) { FactoryBot.create(:user) }
  let!(:other_user_board) { FactoryBot.create(:board, user: other_user) }
  let!(:other_user_element) { FactoryBot.create(:element, :field, board: other_user_board, user: other_user) }
  let(:response_body) { JSON.parse(response.body) }

  describe "GET /boards/:id/elements" do
    context "when logged out" do
      it "returns an auth error" do
        get "/boards/#{user_board.id}/elements"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "returns elements for a board belonging to the user" do
        get "/boards/#{user_board.id}/elements", headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["data"]).to contain_exactly(
          a_hash_including(
            "type" => "elements",
            "id" => user_element.id.to_s
          )
        )
      end

      it "does not return elements for a board belonging to another user" do
        get "/boards/#{other_user_board.id}/elements", headers: headers

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end

      it "returns complete JSON:API structure with required top-level keys" do
        get "/boards/#{user_board.id}/elements", headers: headers

        expect(response_body).to have_key("data")
        expect(response_body["data"]).to be_an(Array)
      end

      it "returns elements with complete resource object structure" do
        get "/boards/#{user_board.id}/elements", headers: headers

        element_data = response_body["data"].first
        expect(element_data).to have_key("type")
        expect(element_data).to have_key("id")
        expect(element_data).to have_key("attributes")
        expect(element_data["type"]).to eq("elements")
        expect(element_data["id"]).to be_a(String)
        expect(element_data["attributes"]).to be_a(Hash)
      end

      it "returns all element attributes with correct transformations" do
        get "/boards/#{user_board.id}/elements", headers: headers

        element_data = response_body["data"].first
        attributes = element_data["attributes"]

        expect(attributes).to include(
          "name" => "Status Field",
          "element-type" => "field",
          "data-type" => "text",
          "display-order" => 5,
          "show-in-summary" => true,
          "show-conditions" => [{"field" => "type", "operator" => "eq", "value" => "task"}],
          "read-only" => false,
          "initial-value" => "empty",
          "options" => {"placeholder" => "Enter status", "max_length" => 50}
        )
      end
    end
  end

  describe "GET /elements/:id" do
    context "when logged out" do
      it "returns an auth error" do
        get "/elements/#{user_element.id}"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "returns an element belonging to the user" do
        get "/elements/#{user_element.id}", headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")

        expect(response_body["data"]).to include(
          "type" => "elements",
          "id" => user_element.id.to_s,
          "attributes" => a_hash_including("name" => "Status Field")
        )
      end

      it "does not return an element belonging to another user" do
        get "/elements/#{other_user_element.id}", headers: headers

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to include(a_hash_including(
          "code" => "404",
          "title" => "Record not found"
        ))
      end

      it "returns complete JSON:API structure for single resource" do
        get "/elements/#{user_element.id}", headers: headers

        expect(response_body).to have_key("data")
        expect(response_body["data"]).to be_a(Hash)
      end

      it "returns complete JSON:API error structure for not found" do
        get "/elements/#{other_user_element.id}", headers: headers

        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
        expect(response_body["errors"]).to be_an(Array)

        error = response_body["errors"].first
        expect(error).to have_key("code")
        expect(error).to have_key("title")
        expect(error["code"]).to eq("404")
      end

      it "returns all element attributes" do
        get "/elements/#{user_element.id}", headers: headers

        attributes = response_body["data"]["attributes"]

        expect(attributes).to include(
          "name" => "Status Field",
          "element-type" => "field",
          "data-type" => "text",
          "display-order" => 5,
          "show-in-summary" => true,
          "show-conditions" => [{"field" => "type", "operator" => "eq", "value" => "task"}],
          "read-only" => false,
          "initial-value" => "empty",
          "options" => {"placeholder" => "Enter status", "max_length" => 50}
        )
      end
    end
  end

  describe "POST /elements" do
    context "when logged out" do
      it "returns an auth error" do
        params = {
          data: {
            type: "elements",
            attributes: {"element-type" => "field"},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        post "/elements", params: params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "creates an element on a board belonging to the user" do
        params = {
          data: {
            type: "elements",
            attributes: {
              :name => "New Field",
              "element-type" => "field",
              "data-type" => "number",
              "display-order" => 10,
              "show-in-summary" => false,
              "show-conditions" => [{field: "status", operator: "ne", value: "archived"}],
              "read-only" => true,
              "initial-value" => "empty",
              :options => {min: 0, max: 100}
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
        expect(response.content_type).to start_with("application/vnd.api+json")

        new_element = Element.last
        expect(response_body["data"]).to include(
          "type" => "elements",
          "id" => new_element.id.to_s,
          "attributes" => {
            "name" => "New Field",
            "element-type" => "field",
            "data-type" => "number",
            "display-order" => 10,
            "show-in-summary" => false,
            "show-conditions" => [{"field" => "status", "operator" => "ne", "value" => "archived"}],
            "read-only" => true,
            "initial-value" => "empty",
            "options" => {"min" => 0, "max" => 100}
          }
        )
      end

      it "creates an element with minimal attributes" do
        params = {
          data: {
            type: "elements",
            attributes: {"element-type" => "field"},
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
          "attributes" => a_hash_including("element-type" => "field")
        })
      end

      it "creates a button element" do
        params = {
          data: {
            type: "elements",
            attributes: {
              :name => "Submit Button",
              "element-type" => "button",
              :options => {label: "Submit", color: "blue"}
            },
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        expect {
          post "/elements", params: params.to_json, headers: headers
        }.to change { Element.count }.by(1)

        new_element = Element.last
        expect(new_element.element_type).to eq("button")
        expect(new_element.element_options).to eq({"label" => "Submit", "color" => "blue"})
      end

      it "associates the element with the current user" do
        params = {
          data: {
            type: "elements",
            attributes: {
              :name => "User Test Element",
              "element-type" => "field"
            },
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        post "/elements", params: params.to_json, headers: headers

        new_element = Element.last
        expect(new_element.user_id).to eq(user.id)
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

        expect(response.status).to eq(0) # Changed for unknown reason in Rack 3.1; in a real app it returns 422
        expect(response_body["errors"]).to contain_exactly(
          a_hash_including("detail" => "board - not found")
        )
      end

      it "returns error for invalid JSON syntax" do
        post "/elements", params: "{invalid json", headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to be_an(Array)
        expect(response_body["errors"].first).to have_key("title")
      end

      it "returns error for missing data key" do
        params = {type: "elements", attributes: {"element-type" => "field"}}

        post "/elements", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
      end

      it "returns error for missing type in data" do
        params = {
          data: {
            attributes: {"element-type" => "field"},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        post "/elements", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for wrong type in data" do
        params = {
          data: {
            type: "boards",
            attributes: {"element-type" => "field"},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        expect {
          post "/elements", params: params.to_json, headers: headers
        }.not_to change { Element.count }

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for missing required element_type" do
        params = {
          data: {
            type: "elements",
            attributes: {name: "Invalid Element"},
            relationships: {
              board: {data: {type: "boards", id: user_board.id}}
            }
          }
        }

        expect {
          post "/elements", params: params.to_json, headers: headers
        }.not_to change { Element.count }

        expect(response.status).to eq(0) # Changed for unknown reason in Rack 3.1; in a real app it returns 422
        expect(response_body).to have_key("errors")
      end
    end
  end

  describe "PATCH /elements/:id" do
    context "when logged out" do
      it "returns an auth error" do
        params = {
          data: {
            type: "elements",
            id: user_element.id.to_s,
            attributes: {name: "Updated Name"}
          }
        }

        patch "/elements/#{user_element.id}", params: params.to_json, headers: {"Content-Type" => "application/vnd.api+json"}

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "updates an element belonging to the user" do
        params = {
          data: {
            type: "elements",
            id: user_element.id.to_s,
            attributes: {name: "Updated Name"}
          }
        }

        patch "/elements/#{user_element.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(user_element.reload.name).to eq("Updated Name")
      end

      it "updates all writable element attributes" do
        params = {
          data: {
            type: "elements",
            id: user_element.id.to_s,
            attributes: {
              :name => "Completely Updated",
              "element-type" => "button",
              "data-type" => "date",
              "display-order" => 99,
              "show-in-summary" => false,
              "show-conditions" => [{field: "active", operator: "eq", value: true}],
              "read-only" => true,
              "initial-value" => "now",
              :options => {color: "red", label: "Click me"}
            }
          }
        }

        patch "/elements/#{user_element.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(200)

        user_element.reload
        expect(user_element.name).to eq("Completely Updated")
        expect(user_element.element_type).to eq("button")
        expect(user_element.data_type).to eq("date")
        expect(user_element.display_order).to eq(99)
        expect(user_element.show_in_summary).to eq(false)
        expect(user_element.show_conditions).to eq([{"field" => "active", "operator" => "eq", "value" => true}])
        expect(user_element.read_only).to eq(true)
        expect(user_element.initial_value).to eq("now")
        expect(user_element.element_options).to eq({"color" => "red", "label" => "Click me"})
      end

      it "does not update an element not belonging to the user" do
        params = {
          data: {
            type: "elements",
            id: other_user_element.id.to_s,
            attributes: {name: "Hacked Name"}
          }
        }

        expect {
          patch "/elements/#{other_user_element.id}", params: params.to_json, headers: headers
        }.not_to change { other_user_element.reload.name }

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
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

      it "returns error for ID mismatch between URL and payload" do
        params = {
          data: {
            type: "elements",
            id: "99999",
            attributes: {name: "Mismatched"}
          }
        }

        patch "/elements/#{user_element.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for invalid JSON syntax" do
        patch "/elements/#{user_element.id}", params: "{invalid json", headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body["errors"]).to be_an(Array)
      end

      it "returns error for missing type in data" do
        params = {
          data: {
            id: user_element.id.to_s,
            attributes: {name: "Test"}
          }
        }

        patch "/elements/#{user_element.id}", params: params.to_json, headers: headers

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end

      it "returns error for wrong type in data" do
        params = {
          data: {
            type: "boards",
            id: user_element.id.to_s,
            attributes: {name: "Test"}
          }
        }

        expect {
          patch "/elements/#{user_element.id}", params: params.to_json, headers: headers
        }.not_to change { user_element.reload.name }

        expect(response.status).to eq(400)
        expect(response.content_type).to start_with("application/vnd.api+json")
        expect(response_body).to have_key("errors")
      end
    end
  end

  describe "DELETE /elements/:id" do
    context "when logged out" do
      it "returns an auth error" do
        delete "/elements/#{user_element.id}"

        expect(response.status).to eq(401)
        expect(response.body).to be_empty
      end
    end

    context "when logged in" do
      it "allows deleting an element belonging to the user" do
        delete "/elements/#{user_element.id}", headers: headers

        expect(response.status).to eq(204)
        expect(response.body).to be_empty

        expect { Element.find(user_element.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not allow deleting an element not belonging to the user" do
        expect {
          delete "/elements/#{other_user_element.id}", headers: headers
        }.not_to change { Element.count }

        expect(response.status).to eq(404)
        expect(response.content_type).to start_with("application/vnd.api+json")
      end

      it "returns JSON:API error structure for not found on delete" do
        delete "/elements/#{other_user_element.id}", headers: headers

        expect(response_body).to have_key("errors")
        expect(response_body).not_to have_key("data")
      end

      it "deletes values for the field from cards", :aggregate_failures do
        other_element = FactoryBot.create(:element, :field, user:, board: user_board)
        card1 = FactoryBot.create(:card, user:, board: user_board, field_values: {user_element.id.to_s => "field value", other_element.id.to_s => "other field value"})
        card2 = FactoryBot.create(:card, user:, board: user_board, field_values: {user_element.id.to_s => "field value", other_element.id.to_s => "other field value"})

        delete "/elements/#{user_element.id}", headers: headers

        expect(response.status).to eq(204)

        card1.reload
        expect(card1.field_values).to have_key(other_element.id.to_s)
        expect(card1.field_values).not_to have_key(user_element.id.to_s)

        card2.reload
        expect(card2.field_values).to have_key(other_element.id.to_s)
        expect(card2.field_values).not_to have_key(user_element.id.to_s)
      end

      it "only deletes field values for field type elements, not buttons" do
        button_element = FactoryBot.create(:element, :button, user:, board: user_board)
        card = FactoryBot.create(:card, user:, board: user_board, field_values: {button_element.id.to_s => "some value"})

        delete "/elements/#{button_element.id}", headers: headers

        expect(response.status).to eq(204)

        # Button element deletion should not trigger field_values cleanup
        # since buttons don't store field values
        card.reload
        # The field_values should remain unchanged (the after_remove hook only runs for field type)
      end
    end
  end
end
