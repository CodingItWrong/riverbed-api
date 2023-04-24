class BoardResource < ApplicationResource
  attributes :name, :icon, :color_theme, :favorited_at

  attribute :options, delegate: :board_options

  relationship :cards, to: :many
  relationship :columns, to: :many
  relationship :elements, to: :many

  before_create do
    _model.user = current_user
  end

  after_create do
    create_initial_board_data
  end

  def self.records(options = {}) = current_user(options).boards

  def self.creatable_fields(_context) = super - [:user]

  def self.updatable_fields(_context) = super - [:user]

  private

  def create_initial_board_data
    _model.columns.create!(user: current_user, name: "All Cards")
    _model.cards.create!(user: current_user)
  end
end
