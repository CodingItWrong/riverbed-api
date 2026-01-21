# frozen_string_literal: true

class JsonapiController < ApplicationController
  private

  def jsonapi_content_type
    "application/vnd.api+json"
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

    {body: body, attributes: data["attributes"] || {}}
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
