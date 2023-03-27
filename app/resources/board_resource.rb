class BoardResource < ApplicationResource
  attributes :name, :icon, :color_theme, :favorited_at

  relationship :cards, to: :many
  relationship :columns, to: :many
  relationship :elements, to: :many

  before_create do
    _model.user = current_user
  end

  def self.records(options = {}) = current_user(options).boards

  def self.creatable_fields(_context) = super - [:user]

  def self.updatable_fields(_context) = super - [:user]
end
