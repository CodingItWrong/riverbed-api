class SharesController < ApplicationController
  before_action :doorkeeper_authorize!

  def create
    attributes = {
      url: link_params[:url],
      title: link_params[:title]
    }

    card = board.cards.create!(
      :user => current_user,
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

  def link_params
    params.permit(:url, :title)
  end

  def board = current_user.ios_share_board

  def field_by_name(name) = board.elements.find_by(element_type: :field, name:)

  def url_field = board.elements.find_by(id: board.board_options["share"]["url-field"])

  def title_field = board.elements.find_by(id: board.board_options["share"]["title-field"])
end
