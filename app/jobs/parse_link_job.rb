# frozen_string_literal: true

require "link_parser"

class ParseLinkJob < ApplicationJob
  def self.parse(link_params)
    perform_later(link_params)
  end

  def perform(link_params)
    parsed_link = link_parser.process(
      url: link_params[:url],
      timeout_seconds: 30
    )

    attributes = {
      url: parsed_link.canonical,
      title: link_params[:title]
    }
    attributes[:title] = parsed_link.title if default_title?(link_params)

    save_link(attributes)
  end

  private

  def link_parser
    LinkParser
  end

  def default_title?(link_params)
    link_params[:title].blank? || link_params[:title] == link_params[:url]
  end

  def save_link(attributes)
    # Once this is extracted from the core API this will be a POST instead of a DB creation
    board.cards.create!("field_values" => {
      url_field.id => attributes[:url],
      title_field.id => attributes[:title]
    })
  end

  def board = Board.find_by(name: "Links")

  def url_field = board.elements.find_by(element_type: :field, name: "URL")

  def title_field = board.elements.find_by(element_type: :field, name: "Title")
end
