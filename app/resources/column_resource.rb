class ColumnResource < ApplicationResource
  attributes :name,
    :display_order,
    :card_grouping,
    :card_inclusion_conditions,
    :summary

  # renamed to avoid issue where JR would silently discard writes
  attribute :card_sort_order, delegate: :sort_order

  relationship :board, to: :one

  before_create do
    _model.user = current_user
  end

  def self.records(options = {})
    user = current_user(options)
    user.columns
  end

  def self.creatable_fields(context)
    super - [:user]
  end

  def self.updatable_fields(context)
    super - [:user, :board]
  end
end
