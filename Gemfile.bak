source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.0.3"
gem "pg", "~> 1.6"
gem "puma"
gem "rack-cors"
gem "jsonapi-resources"
gem "bcrypt"
gem "doorkeeper"
gem "rack", "~> 3.2.4"
gem "ostruct"

# for web hooks
gem "httparty"
gem "csv"

group :development do
  gem "dotenv-rails"
end

group :development, :test do
  gem "coderay"
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "rspec-rails"
  gem "solargraph"
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
