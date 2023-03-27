class AddUserToBoard < ActiveRecord::Migration[7.0]
  def up
    add_reference :boards, :user, null: true, foreign_key: true
    Board.all.each { |b| b.update!(user: User.first) }
    change_column_null :boards, :user_id, false
  end

  def down
    remove_reference :boards, :user, null: false, foreign_key: true
  end
end
