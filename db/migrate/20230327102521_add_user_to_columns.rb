class AddUserToColumns < ActiveRecord::Migration[7.0]
  def up
    add_reference :columns, :user, null: true, foreign_key: true
    Column.all.each { |c| c.update!(user: c.board.user) }
    change_column_null :columns, :user_id, false
  end

  def down
    remove_reference :columns, :user, null: false, foreign_key: true
  end
end
