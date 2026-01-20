# frozen_string_literal: true

class BoardsController < JsonapiController
  before_action :doorkeeper_authorize!

  ORIGINAL_ICONS = %w[
    baseball
    bed
    book
    chart
    checkbox
    food
    gamepad
    link
    map-marker
    medical-bag
    money
    scale
    television
    tree
  ].freeze

  def index
    boards = current_user.boards
    render json: {data: boards.map { |board| serialize_board(board) }}, content_type: jsonapi_content_type
  end

  def show
    board = current_user.boards.find_by(id: params[:id])
    if board
      render json: {data: serialize_board(board)}, content_type: jsonapi_content_type
    else
      render_not_found
    end
  end

  def create
    result = validate_jsonapi_request("boards")
    return if result == :error

    attributes = result[:attributes]

    board = current_user.boards.new(
      name: attributes["name"],
      icon: attributes["icon-extended"] || attributes["icon"],
      color_theme: attributes["color-theme"],
      favorited_at: attributes["favorited-at"],
      board_options: attributes["options"] || {}
    )

    if board.save
      board.columns.create!(user: current_user, name: "All Cards")
      board.cards.create!(user: current_user)
      render json: {data: serialize_board(board)}, status: :created, content_type: jsonapi_content_type
    else
      render_validation_errors(board)
    end
  end

  def update
    board = current_user.boards.find_by(id: params[:id])
    return render_not_found unless board

    result = validate_jsonapi_request("boards", require_id: true, expected_id: params[:id])
    return if result == :error

    attributes = result[:attributes]

    board.name = attributes["name"] if attributes.key?("name")
    board.icon = attributes["icon-extended"] || attributes["icon"] if attributes.key?("icon") || attributes.key?("icon-extended")
    board.color_theme = attributes["color-theme"] if attributes.key?("color-theme")
    board.favorited_at = attributes["favorited-at"] if attributes.key?("favorited-at")
    board.board_options = attributes["options"] if attributes.key?("options")

    if board.save
      render json: {data: serialize_board(board)}, content_type: jsonapi_content_type
    else
      render_validation_errors(board)
    end
  end

  def destroy
    board = current_user.boards.find_by(id: params[:id])
    return render_not_found unless board

    board.destroy
    head :no_content
  end

  private

  def jsonapi_content_type
    "application/vnd.api+json"
  end

  def serialize_board(board)
    {
      type: "boards",
      id: board.id.to_s,
      attributes: {
        "name" => board.name,
        "icon" => ORIGINAL_ICONS.include?(board.icon) ? board.icon : nil,
        "icon-extended" => board.icon,
        "color-theme" => board.color_theme,
        "favorited-at" => board.favorited_at&.as_json,
        "options" => board.board_options
      }
    }
  end

  def validate_jsonapi_request(expected_type, require_id: false, expected_id: nil)
    begin
      body = JSON.parse(request.body.read)
    rescue JSON::ParserError
      render json: {errors: [{code: "400", title: "Invalid JSON"}]}, status: :bad_request, content_type: jsonapi_content_type
      return :error
    end

    unless body.is_a?(Hash) && body.key?("data")
      render json: {errors: [{code: "400", title: "Missing data key"}]}, status: :bad_request, content_type: jsonapi_content_type
      return :error
    end

    data = body["data"]

    unless data.is_a?(Hash) && data["type"] == expected_type
      render json: {errors: [{code: "400", title: "Invalid or missing type"}]}, status: :bad_request, content_type: jsonapi_content_type
      return :error
    end

    if require_id && data["id"] != expected_id
      render json: {errors: [{code: "400", title: "ID mismatch"}]}, status: :bad_request, content_type: jsonapi_content_type
      return :error
    end

    {attributes: data["attributes"] || {}}
  end

  def render_not_found
    render json: {errors: [{code: "404", title: "Record not found"}]}, status: :not_found, content_type: jsonapi_content_type
  end

  def render_validation_errors(record)
    errors = record.errors.map do |error|
      {code: "422", title: error.full_message}
    end
    render json: {errors: errors}, status: :unprocessable_entity, content_type: jsonapi_content_type
  end
end
