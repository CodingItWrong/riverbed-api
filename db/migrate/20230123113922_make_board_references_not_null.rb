class MakeBoardReferencesNotNull < ActiveRecord::Migration[7.0]
  def up
    first_board = Board.first

    Card.update_all(board_id: first_board.id)
    Column.update_all(board_id: first_board.id)
    Element.update_all(board_id: first_board.id)

    change_column_null :cards, :board_id, false
    change_column_null :columns, :board_id, false
    change_column_null :elements, :board_id, false
  end

  def down
    change_column_null :cards, :board_id, true
    change_column_null :columns, :board_id, true
    change_column_null :elements, :board_id, true
  end
end
