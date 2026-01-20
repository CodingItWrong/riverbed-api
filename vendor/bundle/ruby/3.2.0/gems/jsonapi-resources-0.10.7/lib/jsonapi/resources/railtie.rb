module JSONAPI
  module Resources
    class Railtie < Rails::Railtie
      rake_tasks do
        load 'tasks/check_upgrade.rake'
      end
    end
  end
end