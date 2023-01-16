class AddActionToElements < ActiveRecord::Migration[7.0]
  def change
    add_column :elements, :action, :jsonb
  end
end
