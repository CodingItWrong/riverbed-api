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

  before_create do
    _model.user = current_user
  end

  def self.records(options = {})
    user = current_user(options)
    user.elements
  end

  def self.creatable_fields(context)
    super - [:user]
  end

  def self.updatable_fields(context)
    super - [:user, :board]
  end
end
