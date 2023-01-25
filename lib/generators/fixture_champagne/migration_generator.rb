# frozen_string_literal: true

require "rails/generators/named_base"

module FixtureChampagne
  module Generators
    class MigrationGenerator < Rails::Generators::NamedBase
      include Rails::Generators::ResourceHelpers

      source_root File.expand_path("templates", __dir__)

      desc "Generates a migration with the given NAME and a version."

      def generate_migration
        validate_new_migration_file_name!
        template "migration.rb", new_migration_file_path
      end

      private

      def validate_new_migration_file_name!
        return if FixtureChampagne::Migration::MIGRATION_FILENAME_REGEXP.match?(File.basename(new_migration_file_path))

        raise IllegalMigrationNameError, new_migration_file_path
      end

      def new_migration_file_path
        fixture_migrations_path = FixtureChampagne::MigrationContext.fixture_migrations_path
        "#{fixture_migrations_path}/#{new_migration_filename}.rb"
      end

      def new_migration_filename
        @new_migration_filename ||= build_new_migration_filename
      end

      def build_new_migration_filename
        new_migration_version = FixtureChampagne::Migration.new_migration_version
        given_name = file_name
        "#{new_migration_version}_#{given_name}"
      end
    end
  end
end
