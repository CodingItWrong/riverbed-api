class ColumnResource < ApplicationResource
  attributes :name,
    :display_order,
    :card_grouping,
    :card_inclusion_conditions,
    :summary

  # renamed to avoid issue where JR would silently discard writes
  attribute :card_sort_order, delegate: :sort_order

  relationship :board, to: :one
end
