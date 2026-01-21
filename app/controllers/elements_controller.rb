# frozen_string_literal: true

class ElementsController < JsonapiController
  before_action :doorkeeper_authorize!

  def index
    board = current_user.boards.find_by(id: params[:board_id])
    return render_not_found unless board

    elements = board.elements
    render json: {data: elements.map { |element| serialize_element(element) }}, content_type: jsonapi_content_type
  end

  def show
    element = current_user.elements.find_by(id: params[:id])
    if element
      render json: {data: serialize_element(element)}, content_type: jsonapi_content_type
    else
      render_not_found
    end
  end

  def create
    result = validate_jsonapi_request("elements")
    return if result == :error

    attributes = result[:attributes]

    # Extract board from relationships
    begin
      body = JSON.parse(request.body.read)
      request.body.rewind
    rescue JSON::ParserError
      # Already handled in validate_jsonapi_request
      return
    end

    relationships = body.dig("data", "relationships")
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

    # Build element with only provided attributes
    element_params = {user: current_user}
    element_params[:name] = attributes["name"] if attributes.key?("name")
    element_params[:element_type] = attributes["element-type"] if attributes.key?("element-type")
    element_params[:data_type] = attributes["data-type"] if attributes.key?("data-type")
    element_params[:display_order] = attributes["display-order"] if attributes.key?("display-order")
    element_params[:show_in_summary] = attributes["show-in-summary"] if attributes.key?("show-in-summary")
    element_params[:show_conditions] = attributes["show-conditions"] if attributes.key?("show-conditions")
    element_params[:read_only] = attributes["read-only"] if attributes.key?("read-only")
    element_params[:initial_value] = attributes["initial-value"] if attributes.key?("initial-value")
    element_params[:element_options] = attributes["options"] if attributes.key?("options")

    element = board.elements.new(element_params)

    if element.save
      render json: {data: serialize_element(element)}, status: :created, content_type: jsonapi_content_type
    else
      render_validation_errors(element)
    end
  end

  def update
    element = current_user.elements.find_by(id: params[:id])
    return render_not_found unless element

    result = validate_jsonapi_request("elements", require_id: true, expected_id: params[:id])
    return if result == :error

    # Check if relationships are being updated (not allowed for board)
    begin
      body = JSON.parse(request.body.read)
      request.body.rewind
    rescue JSON::ParserError
      # Already handled in validate_jsonapi_request
      return
    end

    if body.dig("data", "relationships")
      render json: {errors: [{code: "400", title: "Updating relationships not allowed"}]}, status: :bad_request, content_type: jsonapi_content_type
      return
    end

    attributes = result[:attributes]

    element.name = attributes["name"] if attributes.key?("name")
    element.element_type = attributes["element-type"] if attributes.key?("element-type")
    element.data_type = attributes["data-type"] if attributes.key?("data-type")
    element.display_order = attributes["display-order"] if attributes.key?("display-order")
    element.show_in_summary = attributes["show-in-summary"] if attributes.key?("show-in-summary")
    element.show_conditions = attributes["show-conditions"] if attributes.key?("show-conditions")
    element.read_only = attributes["read-only"] if attributes.key?("read-only")
    element.initial_value = attributes["initial-value"] if attributes.key?("initial-value")
    element.element_options = attributes["options"] if attributes.key?("options")

    if element.save
      render json: {data: serialize_element(element)}, content_type: jsonapi_content_type
    else
      render_validation_errors(element)
    end
  end

  def destroy
    element = current_user.elements.find_by(id: params[:id])
    return render_not_found unless element

    # Clean up field values from cards if this is a field element
    if element.field?
      key = element.id.to_s
      element.board.cards.find_each do |card|
        if card.field_values.has_key?(key)
          card.field_values.delete(key)
          card.save!
        end
      end
    end

    element.destroy
    head :no_content
  end

  private

  def serialize_element(element)
    {
      type: "elements",
      id: element.id.to_s,
      attributes: {
        "name" => element.name,
        "element-type" => element.element_type,
        "data-type" => element.data_type,
        "display-order" => element.display_order,
        "show-in-summary" => element.show_in_summary,
        "show-conditions" => element.show_conditions,
        "read-only" => element.read_only,
        "initial-value" => element.initial_value,
        "options" => element.element_options
      }
    }
  end
end
