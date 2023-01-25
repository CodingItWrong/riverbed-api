class BoardResource < ApplicationResource
  attribute :name

  relationship :cards, to: :many
  relationship :columns, to: :many
  relationship :elements, to: :many
end
