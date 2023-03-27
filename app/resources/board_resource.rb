class BoardResource < ApplicationResource
  attributes :name, :icon, :color_theme, :favorited_at

  relationship :cards, to: :many
  relationship :columns, to: :many
  relationship :elements, to: :many

  before_create do
    _model.user = current_user
  end

  def self.records(options = {})
    user = current_user(options)
    user.boards
  end

  def self.creatable_fields(context)
    super - [:user]
  end

  def self.updatable_fields(context)
    super - [:user]
  end
end
