# frozen_string_literal: true

module FixtureChampagne
  class Migrator
    attr_reader :direction, :migrations, :target_migration_version, :target_schema_version

    def initialize(direction:, migrations:, target_migration_version:, target_schema_version:)
      @direction = direction
      @migrations = migrations
      @target_migration_version = target_migration_version
      @target_schema_version = target_schema_version
    end

    def migrate
      raise "This method should only run in test environment" unless Rails.env.test?
      
      process_pre_existing_fixtures
      run_migrations
      create_fixture_files_from_test_db      
    end

    def process_pre_existing_fixtures
    end

    def run_migrations
      migrations.each { |m| m.migrate(direction) }
    end

    def create_fixture_files_from_test_db
    end
  end
end
