class AddDisplayOrderToElements < ActiveRecord::Migration[7.0]
  def change
    add_column :elements, :display_order, :integer
    Element.update_all(display_order: 0)
    change_column_null :elements, :display_order, null: false
  end

  def down
    remove_column :elements, :display_order, :integer
  end
end
