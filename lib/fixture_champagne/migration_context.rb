# frozen_string_literal: true

module FixtureChampagne
  class MigrationContext
    class << self
      def migrate
        new(
          fixture_migrations_path: fixture_migrations_path,
          schema_current_version: schema_current_version,
          fixtures_migration_version: fixture_versions["version"],
          fixtures_schema_version: fixture_versions["schema_version"]
        ).migrate
      end

      def fixture_migrations_path
        raise "No fixture_migrations folder found in test suite folder" unless expected_fixture_migrations_path.exist?

        expected_fixture_migrations_path
      end

      def expected_fixture_migrations_path
        test_suite_folder_path.join("fixture_migrations")
      end

      def test_suite_folder_path
        rspec_path = Rails.root.join("test")
        minitest_path = Rails.root.join("spec")

        if minitest_path.exist?
          minitest_path
        elsif rspec_path.exist?
          rspec_path
        else
          raise "No test nor spec folder found"
        end
      end

      def schema_current_version
        ::ActiveRecord::Migrator.current_version
      end

      def fixture_versions
        if fixture_versions_path.exist?
          YAML.safe_load(fixture_versions_path)
        else
          {}
        end
      end

      def fixture_versions_path
        test_suite_folder_path.join(".fixture_versions.yml")
      end
    end

    attr_reader :fixture_migrations_path, :schema_current_version,
                :fixtures_migration_version, :fixtures_schema_version

    def initialize(
      fixture_migrations_path:, schema_current_version:,
      fixtures_migration_version: nil, fixtures_schema_version: nil
    )
      @fixture_migrations_path = fixture_migrations_path
      @schema_current_version = schema_current_version
      @fixtures_migration_version = fixtures_migration_version
      @fixtures_schema_version = fixtures_schema_version
    end

    def migrate
      if pending_migrations.any?
        Migrator.up(pending_migrations)
      elsif fixtures_schema_version != schema_current_version
        Migrator.up([])
      else
        p "No fixture migrations pending."
      end
    end

    def pending_migrations
      return migrations if fixtures_migration_version.nil?

      migrations.select { |m| m.version > fixtures_migration_version }
    end

    def migrations
      migrations = migration_files.map do |file|
        version, name = parse_migration_filename(file)
        raise IllegalMigrationNameError, file unless version

        Migration::Proxy.new(name.camelize, version.to_i, file)
      end

      migrations.sort_by(&:version)
    end

    def migration_files
      Dir["#{fixture_migrations_path}/**/[0-9]*_*.rb"]
    end

    def parse_migration_filename(filename)
      File.basename(filename).scan(Migration::MIGRATION_FILENAME_REGEXP).first
    end
  end
end
