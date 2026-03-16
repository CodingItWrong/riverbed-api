source "https://rubygems.org"

ruby "4.0.1"

gem "rails", "~> 8.1.2"
gem "pg", "~> 1.6"
gem "puma"
gem "rack-cors"
gem "bcrypt"
gem "doorkeeper"

# for web hooks
gem "httparty"

group :development, :test do
  gem "coderay"
  gem "debug"
  gem "rspec-rails"
  gem "standard"
end

group :test do
  gem "factory_bot_rails"
  gem "rspec_junit_formatter"
  gem "vcr"
  gem "webmock"
end

group :production do
  gem "rack-attack"
end
