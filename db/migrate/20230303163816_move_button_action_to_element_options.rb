class MoveButtonActionToElementOptions < ActiveRecord::Migration[7.0]
  def up
    Element
      .where(element_type: :button)
      .each { |b| b.update!(element_options: {actions: [b.action]}) }
    remove_column :elements, :action
  end

  def down
    add_column :elements, :action, :jsonb
    Element
      .where(element_type: :button)
      .each { |b| b.update!(action: b.element_options["actions"][0], element_options: {}) }
  end
end
