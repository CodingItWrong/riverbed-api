require "rails_helper"

RSpec.describe "cards" do
  let(:board) { FactoryBot.create(:board) }

  describe "POST" do
    include_context "with a logged in user"

    it "creates and returns a card" do
      params = {
        data: {
          type: "cards",
          attributes: {},
          relationships: {
            board: {data: {type: "boards", id: board.id}}
          }
        }
      }

      expect {
        post "/cards", params: params.to_json, headers: headers
      }.to change { Card.count }.by(1)

      card = Card.last

      expect(response.status).to eq(201)

      response_body = JSON.parse(response.body)
      expect(response_body["data"]).to include({
        "type" => "cards",
        "id" => card.id.to_s,
        "attributes" => {"field-values" => {}}
      })
    end

    # context "when a field has an initial value of NOW" do
    #   it "sets the initial value of that field to the current date" do
    #     post "/boards/#{board.id}/cards", params: params.to_json

    #     expect(response.status).to eq(201)
    #   end
    # end
  end
end
