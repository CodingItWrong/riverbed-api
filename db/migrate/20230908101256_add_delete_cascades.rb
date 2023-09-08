class AddDeleteCascades < ActiveRecord::Migration[7.0]
  TABLES = %i[boards columns cards elements]

  def up
    TABLES.each do |table|
      remove_foreign_key table, :users
      add_foreign_key table, :users, on_delete: :cascade
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, :users
      add_foreign_key table, :users # no on delete cascade
    end
  end
end
