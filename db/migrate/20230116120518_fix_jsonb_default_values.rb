class FixJsonbDefaultValues < ActiveRecord::Migration[7.0]
  def change
    change_column_default :cards, :field_values, from: "{}", to: {}
    change_column_default :columns, :filter, from: "{}", to: {}
  end
end
