# frozen_string_literal: true

require_relative "test_fixtures"

module FixtureChampagne
  class Migrator
    include TestFixtures

    attr_reader :direction, :migrations, :target_migration_version, :target_schema_version

    def initialize(direction:, migrations:, target_migration_version:, target_schema_version:)
      @direction = direction
      @migrations = migrations
      @target_migration_version = target_migration_version
      @target_schema_version = target_schema_version
    end

    def migrate
      before_migrate

      process_pre_existing_fixtures
      run_migrations
      create_fixture_files_from_test_db

      after_migrate
    end

    def process_pre_existing_fixtures; end

    def run_migrations
      migrations.each { |m| m.migrate(direction: direction, migrator: self) }
    end

    def create_fixture_files_from_test_db; end
  end
end
