class AddInitialValueToElements < ActiveRecord::Migration[7.0]
  def change
    add_column :elements, :initial_value, :integer
  end
end
