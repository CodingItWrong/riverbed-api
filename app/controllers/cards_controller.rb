# frozen_string_literal: true

class CardsController < JsonapiController
  before_action :doorkeeper_authorize!

  def index
    board = current_user.boards.find_by(id: params[:board_id])
    return render_not_found unless board

    cards = board.cards.order(:id)
    render json: {data: cards.map { |card| serialize_card(card) }}, content_type: jsonapi_content_type
  end

  def show
    card = current_user.cards.find_by(id: params[:id])
    if card
      render json: {data: serialize_card(card)}, content_type: jsonapi_content_type
    else
      render_not_found
    end
  end

  def create
    result = validate_jsonapi_request("cards")
    return if result == :error

    attributes = result[:attributes]
    relationships = result[:relationships]

    # Extract board from relationships
    board_id = relationships&.dig("board", "data", "id")

    unless board_id
      render json: {errors: [{code: "400", title: "Missing board relationship"}]}, status: :bad_request, content_type: jsonapi_content_type
      return
    end

    board = current_user.boards.find_by(id: board_id)
    unless board
      # JSONAPI::Resources returns 0 status for some reason in Rack 3.1
      render json: {errors: [{detail: "board - not found"}]}, status: 0, content_type: jsonapi_content_type
      return
    end

    card = board.cards.new(
      user: current_user,
      field_values: attributes["field-values"] || {}
    )

    if card.save
      render json: {data: serialize_card(card)}, status: :created, content_type: jsonapi_content_type
    else
      render_validation_errors(card)
    end
  end

  def update
    card = current_user.cards.find_by(id: params[:id])
    return render_not_found unless card

    result = validate_jsonapi_request("cards", require_id: true, expected_id: params[:id])
    return if result == :error

    attributes = result[:attributes]
    relationships = result[:relationships]

    # Check if relationships are being updated (not allowed for board)
    if relationships
      render json: {errors: [{code: "400", title: "Updating relationships not allowed"}]}, status: :bad_request, content_type: jsonapi_content_type
      return
    end

    card.field_values = attributes["field-values"] if attributes.key?("field-values")

    if card.save
      # Call webhook and merge returned field values
      field_values_to_update = WebhookClient.new("card-update").call(card)
      if field_values_to_update.present?
        card.update!(field_values: card.field_values.merge(field_values_to_update))
      end

      render json: {data: serialize_card(card)}, content_type: jsonapi_content_type
    else
      render_validation_errors(card)
    end
  end

  def destroy
    card = current_user.cards.find_by(id: params[:id])
    return render_not_found unless card

    card.destroy
    head :no_content
  end

  private

  def serialize_card(card)
    {
      type: "cards",
      id: card.id.to_s,
      attributes: {
        "field-values" => card.field_values
      }
    }
  end
end
