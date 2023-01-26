class ColumnResource < ApplicationResource
  attributes :name, :card_inclusion_condition
  attribute :floof, delegate: :sort_order

  relationship :board, to: :one
end
