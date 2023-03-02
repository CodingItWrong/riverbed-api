class AddFavoritedAtToBoard < ActiveRecord::Migration[7.0]
  def change
    add_column :boards, :favorited_at, :datetime
  end
end
