class AddSortToColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :columns, :sort, :jsonb, null: false, default: {}
  end
end
