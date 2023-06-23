namespace :temp do
  desc "Says hello"
  task hello: [:environment] do
    print "hello\n"
  end

  desc "Migrates icons to new names"
  task migrate_text_sizes: [:environment] do
    text_size_mapping = {
      "titleLarge" => 1,
      "titleMedium" => 2,
      "titleSmall" => 3,
      "bodyLarge" => 4,
      "bodyMedium" => 5,
      "bodySmall" => 6
    }

    Element.all.each do |element|
      old_size = element.element_options["text-size"]
      if old_size.present?
        new_size = text_size_mapping[old_size]
        print "Updating Element #{element.id} from #{old_size} to #{new_size}\n"
        element_options = element.element_options
        element_options["text-size"] = new_size
        element.update!(element_options:)
      else
        print "Not updating #{element.id}\n"
      end
    end
  end
end
