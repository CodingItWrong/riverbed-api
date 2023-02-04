class AddDisplayOrderToColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :columns, :display_order, :integer
  end
end
