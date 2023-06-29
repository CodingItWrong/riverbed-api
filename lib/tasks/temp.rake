namespace :temp do
  desc "Says hello"
  task hello: [:environment] do
    print "hello\n"
  end

  desc "Migrates ADD_DAYS commands to new data structure"
  task migrate_add_days: [:environment] do
    Element.where(element_type: :button_menu).map do |button_menu|
      changed = false
      button_menu.element_options["items"].each do |item|
        item["actions"].each_with_index do |action, index|
          if action["command"] == "ADD_DAYS"
            action["specific-value"] = action["value"]
            action.delete("value")
            changed = true
            print "Updating action #{index} for item '#{item["name"]}' for button menu #{button_menu.name}\n"
          else
            print "Not updating action #{index} for item '#{item["name"]}' for button menu #{button_menu.name} because it is a #{action["command"]}\n"
          end
        end
      end

      if changed
        print "Saving button menu #{button_menu.name}\n"
        button_menu.save!
      end
    end
  end
end
