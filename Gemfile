source "https://rubygems.org"

ruby "3.1.3"

gem "rails", "~> 7.0.4"

gem "pg", "~> 1.1"

gem "puma", "~> 5.0"






group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
end

group :development do
end

gem "rack-cors"
gem "jsonapi-resources"
gem "bcrypt"
gem "doorkeeper"

group :development do
  gem "bullet"
  gem "dotenv-rails"
end

group :development, :test do
  gem "rspec-rails"
  gem "coderay"
  gem "standard"
end

group :test do
  gem "factory_bot_rails"
  gem "rspec_junit_formatter"
end
