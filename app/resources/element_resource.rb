class ElementResource < ApplicationResource
  attributes :name,
    :element_type,
    :data_type,
    :display_order,
    :show_in_summary,
    :show_condition,
    :read_only,
    :action
end