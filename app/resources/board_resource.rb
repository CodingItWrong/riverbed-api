class BoardResource < ApplicationResource
  attributes :name, :icon, :color_theme, :favorited_at

  relationship :cards, to: :many
  relationship :columns, to: :many
  relationship :elements, to: :many
end
