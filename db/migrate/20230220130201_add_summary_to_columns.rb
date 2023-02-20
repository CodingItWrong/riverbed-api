class AddSummaryToColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :columns, :summary, :jsonb, null: false, default: {}
  end
end
