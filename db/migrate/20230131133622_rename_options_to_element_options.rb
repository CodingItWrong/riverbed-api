class RenameOptionsToElementOptions < ActiveRecord::Migration[7.0]
  def change
    rename_column :elements, :options, :element_options
  end
end
