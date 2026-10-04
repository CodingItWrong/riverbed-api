# frozen_string_literal: true

class ColumnsController < JsonapiController
  before_action :doorkeeper_authorize!

  def index
    board = current_user.boards.find_by(id: params[:board_id])
    return render_not_found unless board

    columns = board.columns.order(:id)
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

    attributes = result[:attributes]
    relationships = result[:relationships]

    # Check if relationships are being updated (not allowed for board)
    if relationships
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

  def cards
    column = current_user.columns.find_by(id: params[:id])
    return render_not_found unless column

    timezone = params[:timezone].presence || "UTC"
    unless valid_timezone?(timezone)
      render json: {errors: [{code: "422", title: "Invalid timezone",
                              detail: "timezone - is not a valid IANA timezone"}]},
        status: :unprocessable_entity, content_type: jsonapi_content_type
      return
    end

    filtered = filter_cards(column, timezone)

    render json: {data: filtered.map { |card| serialize_card(card) }},
      content_type: jsonapi_content_type
  end

  def destroy
    column = current_user.columns.find_by(id: params[:id])
    return render_not_found unless column

    column.destroy
    head :no_content
  end

  private

  # CARD_FILTERING chooses how column conditions are applied during the move
  # from Ruby to SQL (see docs/sql-card-filtering-plan.md):
  # - "ruby" (default): load every card on the board and filter in Ruby
  # - "sql": filter in the database
  # - "compare": filter both ways, log any difference, and return the Ruby result
  def filter_cards(column, timezone)
    elements_by_id = column.board.elements.index_by { |e| e.id.to_s }
    conditions = column.card_inclusion_conditions
    cards = column.board.cards

    case ENV.fetch("CARD_FILTERING", "ruby")
    when "sql"
      sql_filtered_cards(cards, conditions, elements_by_id, timezone)
    when "compare"
      ruby_cards = ruby_filtered_cards(cards, conditions, elements_by_id, timezone)
      compare_card_filtering(column, ruby_cards) do
        sql_filtered_cards(cards, conditions, elements_by_id, timezone)
      end
      ruby_cards
    else
      ruby_filtered_cards(cards, conditions, elements_by_id, timezone)
    end
  end

  def ruby_filtered_cards(cards, conditions, elements_by_id, timezone)
    evaluator = CardConditionEvaluator.new(conditions, elements_by_id, timezone: timezone)
    cards.order(:id).select { |card| evaluator.passes?(card) }
  end

  def sql_filtered_cards(cards, conditions, elements_by_id, timezone)
    CardConditionQuery.new(conditions, elements_by_id, timezone: timezone).apply(cards).order(:id).to_a
  end

  # Logs card IDs and conditions only, not field values, since they're user content
  def compare_card_filtering(column, ruby_cards)
    ruby_ids = ruby_cards.map(&:id)
    sql_ids = yield.map(&:id)
    return if sql_ids == ruby_ids

    Rails.logger.warn(
      "Card filtering mismatch for column #{column.id}: " \
      "only in Ruby #{(ruby_ids - sql_ids).inspect}, only in SQL #{(sql_ids - ruby_ids).inspect}, " \
      "conditions #{column.card_inclusion_conditions.to_json}"
    )
  rescue => e
    Rails.logger.error("Card filtering comparison failed for column #{column.id}: #{e.class}: #{e.message}")
  end

  def valid_timezone?(tz_name)
    ActiveSupport::TimeZone.find_tzinfo(tz_name)
    true
  rescue TZInfo::InvalidTimezoneIdentifier
    false
  end

  def serialize_card(card)
    {
      type: "cards",
      id: card.id.to_s,
      attributes: {
        "field-values" => card.field_values
      }
    }
  end

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
