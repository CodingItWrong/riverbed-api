class AddIconToBoards < ActiveRecord::Migration[7.0]
  def change
    add_column :boards, :icon, :string
  end
end
