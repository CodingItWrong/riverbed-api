class RenameElementsShowConditionToShowConditions < ActiveRecord::Migration[7.0]
  def up
    add_column :elements, :show_conditions, :jsonb, null: false, default: []
    Element
      .all
      .each do |e|
        e.update!(
          show_conditions:
            (e.show_condition.present? ? [e.show_condition] : [])
        )
      end
    remove_column :elements, :show_condition
  end

  def down
    add_column :elements, :show_condition, :jsonb
    Element
      .all
      .each do |e|
        e.update!(
          show_condition:
            (e.show_conditions.empty? ? nil : e.show_conditions.first)
        )
      end
    remove_column :elements, :show_conditions
  end
end
