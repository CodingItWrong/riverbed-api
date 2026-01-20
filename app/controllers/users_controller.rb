# frozen_string_literal: true

class UsersController < JsonapiController
  before_action :doorkeeper_authorize!, except: [:create]
  before_action :set_user, only: [:show, :update, :destroy]

  def show
    if @user
      render json: {data: serialize_user(@user)}, content_type: jsonapi_content_type
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
    return render_not_found unless @user

    result = validate_jsonapi_request("users", require_id: true, expected_id: params[:id])
    return if result == :error

    attributes = result[:attributes]

    @user.email = attributes["email"] if attributes.key?("email")
    @user.password = attributes["password"] if attributes.key?("password")
    @user.allow_emails = attributes["allow-emails"] if attributes.key?("allow-emails")
    @user.ios_share_board_id = attributes["ios-share-board-id"] if attributes.key?("ios-share-board-id")

    if @user.save
      render json: {data: serialize_user(@user)}, content_type: jsonapi_content_type
    else
      render_validation_errors(@user)
    end
  end

  def destroy
    return render_not_found unless @user

    @user.destroy
    head :no_content
  end

  private

  def set_user
    @user = if current_user&.id == params[:id].to_i
              current_user
            else
              nil
            end
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
end
