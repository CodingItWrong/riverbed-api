class AddOptionsToBoards < ActiveRecord::Migration[7.0]
  def change
    add_column :boards, :board_options, :jsonb, null: false, default: {}
  end
end
