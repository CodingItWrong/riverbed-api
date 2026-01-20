# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :doorkeeper_authorize!, except: [:create]

  def show
    user = User.find_by(id: params[:id])
    if user && user == current_user
      render json: {data: serialize_user(user)}, content_type: jsonapi_content_type
    else
      render_not_found
    end
  end

  def create
    result = validate_jsonapi_request("users")
    return if result == :error

    attributes = result[:attributes]

    user = User.new(
      email: attributes["email"],
      password: attributes["password"],
      allow_emails: attributes["allow-emails"],
      ios_share_board_id: attributes["ios-share-board-id"]
    )

    if user.save
      render json: {data: serialize_user(user)}, status: :created, content_type: jsonapi_content_type
    else
      render_validation_errors(user)
    end
  end

  def update
    user = User.find_by(id: params[:id])
    return render_not_found unless user && user == current_user

    result = validate_jsonapi_request("users", require_id: true, expected_id: params[:id])
    return if result == :error

    attributes = result[:attributes]

    user.password = attributes["password"] if attributes.key?("password")
    user.allow_emails = attributes["allow-emails"] if attributes.key?("allow-emails")
    user.ios_share_board_id = attributes["ios-share-board-id"] if attributes.key?("ios-share-board-id")

    if user.save
      render json: {data: serialize_user(user)}, content_type: jsonapi_content_type
    else
      render_validation_errors(user)
    end
  end

  def destroy
    user = User.find_by(id: params[:id])
    return render_not_found unless user && user == current_user

    user.destroy
    head :no_content
  end

  private

  def jsonapi_content_type
    "application/vnd.api+json"
  end

  def serialize_user(user)
    {
      type: "users",
      id: user.id.to_s,
      attributes: {
        "allow-emails" => user.allow_emails,
        "ios-share-board-id" => user.ios_share_board_id
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
      {code: "422", title: error.full_message, detail: "#{error.attribute} - #{error.message}"}
    end
    render json: {errors: errors}, status: :unprocessable_entity, content_type: jsonapi_content_type
  end
end
