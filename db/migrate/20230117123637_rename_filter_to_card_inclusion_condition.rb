class RenameFilterToCardInclusionCondition < ActiveRecord::Migration[7.0]
  def change
    rename_column :columns, :filter, :card_inclusion_condition
  end
end
