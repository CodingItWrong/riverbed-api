# frozen_string_literal: true

# Minimal resource to support nested routes for cards, columns, and elements.
# Board CRUD operations are handled directly by BoardsController.
class BoardResource < ApplicationResource
  # Relationships needed for nested routes like /boards/:board_id/cards
  relationship :cards, to: :many
  relationship :columns, to: :many
  relationship :elements, to: :many

  # Scope boards to current user for authorization on nested routes
  def self.records(options = {}) = current_user(options).boards
end
