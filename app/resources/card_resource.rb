class CardResource < ApplicationResource
  attribute :field_values

  relationship :board, to: :one
end
