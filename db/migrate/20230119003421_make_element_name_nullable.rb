class MakeElementNameNullable < ActiveRecord::Migration[7.0]
  def change
    change_column_null :elements, :name, true
  end
end
