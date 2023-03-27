class AddUserToElements < ActiveRecord::Migration[7.0]
  def up
    add_reference :elements, :user, null: true, foreign_key: true
    Element.all.each { |e| e.update!(user: e.board.user) }
    change_column_null :elements, :user_id, false
  end

  def down
    remove_reference :elements, :user, null: false, foreign_key: true
  end
end
