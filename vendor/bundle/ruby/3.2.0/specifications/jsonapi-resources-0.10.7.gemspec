# -*- encoding: utf-8 -*-
# stub: jsonapi-resources 0.10.7 ruby lib

Gem::Specification.new do |s|
  s.name = "jsonapi-resources".freeze
  s.version = "0.10.7"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Dan Gebhardt".freeze, "Larry Gebhardt".freeze]
  s.date = "2022-03-09"
  s.description = "A resource-centric approach to implementing the controllers, routes, and serializers needed to support the JSON API spec.".freeze
  s.email = ["dan@cerebris.com".freeze, "larry@cerebris.com".freeze]
  s.homepage = "https://github.com/cerebris/jsonapi-resources".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Easily support JSON API in Rails.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, [">= 1.17"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.10", "!= 5.10.2"])
  s.add_development_dependency(%q<minitest-spec-rails>.freeze, [">= 0"])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry>.freeze, [">= 0"])
  s.add_development_dependency(%q<concurrent-ruby-ext>.freeze, [">= 0"])
  s.add_development_dependency(%q<database_cleaner>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 4.1"])
  s.add_runtime_dependency(%q<railties>.freeze, [">= 4.1"])
  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, [">= 0"])
end
