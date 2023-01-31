class ElementResource < ApplicationResource
  attributes :name,
    :element_type,
    :data_type,
    :display_order,
    :show_in_summary,
    :show_condition,
    :read_only,
    :action

  # renamed to avoid issue where JR would silently discard writes
  attribute :options, delegate: :element_options

  relationship :board, to: :one
end
