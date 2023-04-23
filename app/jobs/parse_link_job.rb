# frozen_string_literal: true

class ParseLinkJob < ApplicationJob
  def self.parse(link_params)
    perform_later(link_params)
  end

  def perform(link_params)
    attributes = {
      url: link_params[:url],
      title: link_params[:title]
    }

    save_link(attributes)
  end

  private

  def save_link(attributes)
    # Once this is extracted from the core API this will be a POST instead of a DB creation
    board.cards.create!(
      :user => board.user, # TODO: look up board by hard-coded ID so doesn't conflict with someone else's
      "field_values" => {
        url_field.id => attributes[:url],
        title_field.id => attributes[:title]
      }
    )
  end

  def board = Board.find_by(name: "Links")

  def field_by_name(name) = board.elements.find_by(element_type: :field, name:)

  def url_field = field_by_name("URL")

  def title_field = field_by_name("Title")
end
