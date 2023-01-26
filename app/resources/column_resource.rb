class ColumnResource < ApplicationResource
  attributes :name, :card_inclusion_condition, :sort

  relationship :board, to: :one
end
