class AddElementType < ActiveRecord::Migration[7.0]
  def up
    add_column :elements, :element_type, :integer
    Element.update_all(element_type: :field)
    change_column_null :elements, :element_type, false
  end

  def down
    remove_column :elements, :element_type, :integer
  end
end
