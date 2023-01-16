class MakeDataTypeNullable < ActiveRecord::Migration[7.0]
  def change
    change_column_null :elements, :data_type, true
  end
end
