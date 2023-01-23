# frozen_string_literal: true

require_relative "lib/fixture_champagne/version"

Gem::Specification.new do |spec|
  spec.name = "fixture_champagne"
  spec.version = FixtureChampagne::VERSION
  spec.authors = ["Juan Gueçaimburu"]
  spec.email = ["guecaimburu.j@gmail.com"]

  spec.summary = "Fixture migrations for Ruby on Rails applications"
  spec.description = <<~DESCRIPTION
    Data migration pattern applied to fixtures.
    Create, update and keep fixtures synced with db schema.
  DESCRIPTION

  spec.homepage = "https://github.com/jguecaimburu/fixture_champagne"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/jguecaimburu/fixture_champagne/CHANGELOG.md"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 6.0.0"
  spec.metadata["rubygems_mfa_required"] = "true"
end
