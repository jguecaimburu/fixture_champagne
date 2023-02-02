# frozen_string_literal: true

module FixtureChampagne
  module Generators
    # MigrationGenerator generates a new migration using the migration.rb.tt template.
    #
    # Ensure that a fixture_migrations folder exists in your test suite folder or create one
    # running the install generator. This folder is set at FixtureChampagne::MigrationContext.fixture_migrations_path
    # Then from your app directory you can run:
    #
    # bin/rails generate fixture_champagne:migration <new_migration_name>
    #
    # Where <new_migration_name> should be the name of your new migration. For example:
    # bin/rails generate fixture_champagne:migration add_new_user
    #
    # Will generate fixture_migrations/20230126153650_add_new_user.rb with the following content:
    #   class AddTurtle < FixtureChampagne::Migration::Base
    #     def up
    #       # Create, update or destroy records here
    #     end
    #
    #     def down
    #       # Optionally, reverse changes made by the :up method
    #     end
    #   end
    #
    # The generator automatically adds a version number to the new migration file, which is important
    # to keep track of executed migrations. Also, the migration filename must correspond with the migration
    # class inside the file.
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
