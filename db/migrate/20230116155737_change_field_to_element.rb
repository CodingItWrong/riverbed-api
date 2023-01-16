class ChangeFieldToElement < ActiveRecord::Migration[7.0]
  def change
    rename_table :fields, :elements
  end
end
