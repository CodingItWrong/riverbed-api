class RenameSortToSortOrder < ActiveRecord::Migration[7.0]
  def change
    rename_column :columns, :sort, :sort_order
  end
end
