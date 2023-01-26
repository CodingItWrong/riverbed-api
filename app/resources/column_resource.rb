class ColumnResource < ApplicationResource
  attributes :name, :card_inclusion_condition, :sort_order

  relationship :board, to: :one
end
