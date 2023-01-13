class AddDataTypeToFields < ActiveRecord::Migration[7.0]
  def up
    add_column :fields, :data_type, :integer
    Field.update_all(data_type: :text)
    change_column_null :fields, :data_type, false
  end

  def down
    remove_column :fields, :data_type, :integer
  end
end
