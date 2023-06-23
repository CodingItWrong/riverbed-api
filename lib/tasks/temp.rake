namespace :temp do
  desc "Says hello"
  task hello: [:environment] do
    print "hello\n"
  end

  desc "Migrates icons to new names"
  task migrate_icons: [:environment] do
    icon_mapping = {
      "bed-king-outline" => "bed",
      "book-open-outline" => "book",
      "chart-timeline" => "chart",
      "checkbox-outline" => "checkbox",
      "gamepad-variant" => "gamepad",
      "scale-bathroom" => "scale"
    }

    Board.all.each do |board|
      if icon_mapping.has_key?(board.icon)
        new_icon = icon_mapping[board.icon]
        print "Updating #{board.name} from #{board.icon} to #{new_icon}\n"
        board.update!(icon: new_icon)
      else
        print "Not updating #{board.name} with icon #{board.icon}\n"
      end
    end
  end
end
