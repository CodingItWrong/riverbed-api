class AddColorThemeToBoards < ActiveRecord::Migration[7.0]
  def change
    add_column :boards, :color_theme, :string
  end
end
