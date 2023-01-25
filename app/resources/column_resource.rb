class ColumnResource < ApplicationResource
  attributes :name, :card_inclusion_condition

  relationship :board, to: :one
end
