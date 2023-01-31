class AddOptionsToElements < ActiveRecord::Migration[7.0]
  def change
    add_column :elements, :options, :jsonb, null: false, default: {}
  end
end
