class AddCardGroupingToColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :columns, :card_grouping, :jsonb, null: false, default: {}
  end
end
