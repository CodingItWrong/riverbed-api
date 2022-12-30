class CreateCards < ActiveRecord::Migration[7.0]
  def change
    create_table :cards do |t|
      t.jsonb :field_values, null: false, default: "{}"

      t.timestamps
    end
  end
end
