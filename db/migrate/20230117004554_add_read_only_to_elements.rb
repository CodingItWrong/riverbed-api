class AddReadOnlyToElements < ActiveRecord::Migration[7.0]
  def change
    add_column :elements, :read_only, :boolean, null: false, default: false
  end
end
