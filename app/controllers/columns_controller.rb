# frozen_string_literal: true

class ColumnsController < JsonapiController
  before_action :doorkeeper_authorize!

  def index
    board = current_user.boards.find_by(id: params[:board_id])
    return render_not_found unless board

    columns = board.columns
    render json: {data: columns.map { |column| serialize_column(column) }}, content_type: jsonapi_content_type
  end

  def show
    column = current_user.columns.find_by(id: params[:id])
    if column
      render json: {data: serialize_column(column)}, content_type: jsonapi_content_type
    else
      render_not_found
    end
  end

  def create
    result = validate_jsonapi_request("columns")
    return if result == :error

    attributes = result[:attributes]
    body = result[:body]

    # Extract board from relationships
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

    column = board.columns.new(
      user: current_user,
      name: attributes["name"],
      display_order: attributes["display-order"],
      sort_order: attributes["card-sort-order"] || {},
      card_inclusion_conditions: attributes["card-inclusion-conditions"] || [],
      card_grouping: attributes["card-grouping"] || {},
      summary: attributes["summary"] || {}
    )

    if column.save
      render json: {data: serialize_column(column)}, status: :created, content_type: jsonapi_content_type
    else
      render_validation_errors(column)
    end
  end

  def update
    column = current_user.columns.find_by(id: params[:id])
    return render_not_found unless column

    result = validate_jsonapi_request("columns", require_id: true, expected_id: params[:id])
    return if result == :error

    body = result[:body]
    attributes = result[:attributes]

    # Check if relationships are being updated (not allowed for board)
    if body.dig("data", "relationships")
      render json: {errors: [{code: "400", title: "Updating relationships not allowed"}]}, status: :bad_request, content_type: jsonapi_content_type
      return
    end

    column.name = attributes["name"] if attributes.key?("name")
    column.display_order = attributes["display-order"] if attributes.key?("display-order")
    column.sort_order = attributes["card-sort-order"] if attributes.key?("card-sort-order")
    column.card_inclusion_conditions = attributes["card-inclusion-conditions"] if attributes.key?("card-inclusion-conditions")
    column.card_grouping = attributes["card-grouping"] if attributes.key?("card-grouping")
    column.summary = attributes["summary"] if attributes.key?("summary")

    if column.save
      render json: {data: serialize_column(column)}, content_type: jsonapi_content_type
    else
      render_validation_errors(column)
    end
  end

  def destroy
    column = current_user.columns.find_by(id: params[:id])
    return render_not_found unless column

    column.destroy
    head :no_content
  end

  private

  def serialize_column(column)
    {
      type: "columns",
      id: column.id.to_s,
      attributes: {
        "name" => column.name,
        "display-order" => column.display_order,
        "card-sort-order" => column.sort_order,
        "card-inclusion-conditions" => column.card_inclusion_conditions,
        "card-grouping" => column.card_grouping,
        "summary" => column.summary
      }
    }
  end
end
