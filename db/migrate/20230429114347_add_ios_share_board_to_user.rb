class AddIosShareBoardToUser < ActiveRecord::Migration[7.0]
  def change
    add_reference :users, :ios_share_board, null: true, foreign_key: {to_table: :boards}
  end
end
