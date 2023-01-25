class DefaultShowInSummaryToFalse < ActiveRecord::Migration[7.0]
  def change
    change_column_default :elements, :show_in_summary, from: true, to: false
  end
end
