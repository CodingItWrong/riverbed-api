class ElementResource < ApplicationResource
  attributes :name,
    :element_type,
    :data_type,
    :show_in_summary,
    :read_only,
    :action
end
