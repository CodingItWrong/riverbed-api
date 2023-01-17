class AddShowConditionToElements < ActiveRecord::Migration[7.0]
  def change
    add_column :elements, :show_condition, :jsonb
  end
end
