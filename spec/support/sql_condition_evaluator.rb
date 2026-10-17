# frozen_string_literal: true

# Adapts CardConditionQuery to the `passes?(card)` interface the shared
# "card condition filtering" examples use: it saves a real card row with the
# given field values and checks whether the query includes it, so the
# examples exercise the actual SQL.
class SqlConditionEvaluator
  def initialize(query, board)
    @query = query
    @board = board
  end

  def passes?(card)
    record = Card.create!(board: @board, user: @board.user, field_values: card.field_values)
    @query.apply(Card.where(id: record.id)).exists?
  end
end
