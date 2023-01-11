class AddShowInSummaryToFields < ActiveRecord::Migration[7.0]
  def change
    add_column :fields, :show_in_summary, :boolean, null: false, default: true
  end
end
