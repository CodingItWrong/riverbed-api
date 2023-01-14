class CreateColumns < ActiveRecord::Migration[7.0]
  def change
    create_table :columns do |t|
      t.string :name, null: false
      t.jsonb :filter, null: false, default: "{}"

      t.timestamps
    end
  end
end
