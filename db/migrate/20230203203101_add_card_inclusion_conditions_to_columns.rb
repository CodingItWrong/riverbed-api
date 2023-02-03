class AddCardInclusionConditionsToColumns < ActiveRecord::Migration[7.0]
  def up
    add_column :columns, :card_inclusion_conditions, :jsonb, null: false, default: []
    Column.all.each do |c|
      c.update!(card_inclusion_conditions: [c.card_inclusion_condition])
    end
    remove_column :columns, :card_inclusion_condition
  end

  def down
    add_column :columns, :card_inclusion_condition, null: false, default: {}
    remove_column :columns, :card_inclusion_conditions
  end
end
