class AddBoardRelationToModels < ActiveRecord::Migration[7.0]
  def change
    add_reference :cards, :board, foreign_key: true
    add_reference :columns, :board, foreign_key: true
    add_reference :elements, :board, foreign_key: true
  end
end
