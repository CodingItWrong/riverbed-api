class AddUserToCards < ActiveRecord::Migration[7.0]
  def up
    add_reference :cards, :user, null: true, foreign_key: true
    Card.all.each { |c| c.update!(user: c.board.user) }
    change_column_null :cards, :user_id, false
  end

  def down
    remove_reference :cards, :user, null: false, foreign_key: true
  end
end
