source "https://rubygems.org"

ruby "3.2.0"

gem "rails", "~> 7.0.4"
gem "pg", "~> 1.4"
gem "puma"
gem "rack-cors"
gem "jsonapi-resources"
gem "bcrypt"
gem "doorkeeper"

# for temporary link parsing
gem "httparty"

group :development do
  gem "bullet"
  gem "dotenv-rails"
end

group :development, :test do
  gem "coderay"
  gem "debug", platforms: %i[mri mingw x64_mingw]
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
