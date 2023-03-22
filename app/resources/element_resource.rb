class ElementResource < ApplicationResource
  attributes :name,
    :element_type,
    :data_type,
    :initial_value,
    :display_order,
    :show_in_summary,
    :show_conditions,
    :read_only

  # renamed to avoid issue where JR would silently discard writes
  attribute :options, delegate: :element_options

  relationship :board, to: :one
end
