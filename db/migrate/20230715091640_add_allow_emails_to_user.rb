class AddAllowEmailsToUser < ActiveRecord::Migration[7.0]
  def up
    add_column :users, :allow_emails, :boolean, null: true
    User.update_all(allow_emails: false)
    change_column :users, :allow_emails, :boolean, null: false
  end

  def down
    remove_column :users, :allow_emails, :boolean, null: false
  end
end
