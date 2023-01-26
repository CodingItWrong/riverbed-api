class ColumnResource < ApplicationResource
  attributes :name, :card_inclusion_condition

  # renamed to avoid issue where JR would silently discard writes
  attribute :card_sort_order, delegate: :sort_order

  relationship :board, to: :one
end
