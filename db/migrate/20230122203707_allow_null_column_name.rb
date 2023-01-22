class AllowNullColumnName < ActiveRecord::Migration[7.0]
  def change
    change_column_null :columns, :name, true
  end
end
