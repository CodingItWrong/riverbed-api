class SharesController < ActionController::Base
  before_action :verify_api_key

  def create
    attributes = {
      url: link_params[:url],
      title: link_params[:title]
    }

    card = board.cards.create!(
      :user => user_for_api_key,
      "field_values" => {
        url_field.id => attributes[:url],
        title_field.id => attributes[:title]
      }
    )

    # TODO: rework the code so we can get the attributes before saving the card
    field_values_to_update = WebhookClient.new("card-create").call(card)
    if field_values_to_update.present?
      card.update!(field_values: card.field_values.merge(field_values_to_update))
    end

    head :no_content
  end

  private

  def user_for_api_key
    provided_header = request.headers["HTTP_AUTHORIZATION"]
    return nil unless provided_header.present?

    key = provided_header.gsub(/^Bearer /i, "")
    ApiKey.find_by(key:)&.user
  end

  def verify_api_key
    head :unauthorized unless user_for_api_key.present?
  end

  def link_params
    params.permit(:url, :title)
  end

  def board = user_for_api_key.boards.find_by(name: "Links")

  def field_by_name(name) = board.elements.find_by(element_type: :field, name:)

  def url_field = board.elements.find_by(id: board.board_options["share"]["url-field"])

  def title_field = board.elements.find_by(id: board.board_options["share"]["title-field"])
end
