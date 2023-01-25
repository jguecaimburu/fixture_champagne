# frozen_string_literal: true

require "rails/generators/named_base"

module FixtureChampagne
  module Generators
    class MigrationGenerator < Rails::Generators::NamedBase
      include Rails::Generators::ResourceHelpers

      source_root File.expand_path("templates", __dir__)

      desc "Generates a migration with the given NAME and a version."

      def generate_notification
        template "migration.rb",
                 "#{MigrationContext.fixture_migrations_path}/#{Migration.new_migration_version}#{file_name}.rb"
      end
    end
  end
end
