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

  after_remove do
    if _model.field?
      key = _model.id.to_s
      _model.board.cards.find_each do |card|
        if card.field_values.has_key?(key)
          card.field_values.delete(key)
          card.save!
        end
      end
    end
  end

  def self.records(options = {}) = current_user(options).elements

  def self.creatable_fields(_context) = super - [:user]

  def self.updatable_fields(_context) = super - [:user, :board]
end
