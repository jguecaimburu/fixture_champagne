# frozen_string_literal: true

module FixtureChampagne
  # MigrationContext sets the context in which a fixture migration is run.
  #
  # A migration context checks where the application files are located, which could be
  # in /test if the app uses Minitest or /spec if the app uses RSpec, and from that base
  # it decides where everything else is located:
  # - Fixture migrations folder
  # - Configuration YAML file
  # - Saved versions YAML file
  # - Fixtures path
  #
  # With all that it decides which migrations are pending, which are executed and the target
  # versions. Depending on the method called, it also decides the direction the Migrator should execute.
  class MigrationContext
    MINITEST_PATH = Rails.root.join("test")
    RSPEC_PATH = Rails.root.join("spec")

    class << self
      def migrate
        raise NotInTestEnvironmentError unless Rails.env.test?

        build_context.migrate
      end

      def rollback
        build_context.rollback
      end

      def build_context
        new(
          fixture_migrations_path: fixture_migrations_path,
          schema_current_version: schema_current_version,
          fixtures_migration_version: fixture_versions["version"]&.to_i || 0,
          fixtures_schema_version: fixture_versions["schema_version"]&.to_i || 0,
          configuration: configuration
        )
      end

      def fixture_migrations_path
        raise MissingMigrationsFolderError unless expected_fixture_migrations_path.exist?

        expected_fixture_migrations_path
      end

      def expected_fixture_migrations_path
        test_suite_folder_path.join("fixture_migrations")
      end

      def test_suite_folder_path
        if test_framework == :rspec && RSPEC_PATH.exist?
          RSPEC_PATH
        elsif MINITEST_PATH.exist?
          MINITEST_PATH
        else
          raise "No test nor spec folder found. Tried: #{[MINITEST_PATH, RSPEC_PATH].to_json}"
        end
      end

      def test_framework
        ::Rails.application.config.generators.options[:rails][:test_framework]
      end

      def schema_current_version
        ::ActiveRecord::Migrator.current_version
      end

      def fixture_versions
        @fixture_versions ||= if fixture_versions_path.exist?
                                YAML.load_file(fixture_versions_path)
                              else
                                {}
                              end
      end

      def fixture_versions_path
        test_suite_folder_path.join(".fixture_champagne_versions.yml")
      end

      def configuration
        @configuration ||= if configuration_path.exist?
                             Configuration.new(YAML.load_file(configuration_path))
                           else
                             Configuration.new({})
                           end
      end

      def configuration_path
        test_suite_folder_path.join("fixture_champagne.yml")
      end

      def fixture_paths
        paths = if test_framework == :rspec
                  rspec_fixture_paths
                else
                  minitest_fixture_paths
                end
        paths.map { |p| Pathname.new(p) }
      end

      def minitest_fixture_paths
        MinitestConfig.new(MINITEST_PATH).fixture_paths
      end

      def rspec_fixture_paths
        RSpecConfig.new(RSPEC_PATH).fixture_paths
      end
    end

    attr_reader :fixture_migrations_path, :schema_current_version,
                :fixtures_migration_version, :fixtures_schema_version, :configuration

    def initialize(
      fixture_migrations_path:, schema_current_version:,
      fixtures_migration_version:, fixtures_schema_version:,
      configuration:
    )
      @fixture_migrations_path = fixture_migrations_path
      @schema_current_version = schema_current_version
      @fixtures_migration_version = fixtures_migration_version
      @fixtures_schema_version = fixtures_schema_version
      @configuration = configuration
    end

    def migrate
      # If rename_fixtures? is set to true, the migration should run as some label could have changed.
      if pending_migrations.any? || fixtures_schema_version != schema_current_version || configuration.rename_fixtures?
        up
      else
        puts "No fixture migrations pending."
      end
    end

    def rollback
      if executed_migrations.any?
        down
      else
        puts "No migration to rollback."
      end
    end

    def up
      Migrator.new(
        direction: :up,
        migrations: pending_migrations,
        target_migration_version: up_target_fixture_migration_version,
        target_schema_version: schema_current_version,
        configuration: configuration
      ).migrate
    end

    def down
      Migrator.new(
        direction: :down,
        migrations: [executed_migrations.last],
        target_migration_version: down_target_fixture_migration_version,
        target_schema_version: schema_current_version,
        configuration: configuration
      ).migrate
    end

    def up_target_fixture_migration_version
      return fixtures_migration_version if pending_migrations.empty?

      pending_migrations.map(&:version).max
    end

    def down_target_fixture_migration_version
      return 0 if executed_migrations.one?

      executed_migrations.last(2).first.version
    end

    def pending_migrations
      migrations.select { |m| m.version > fixtures_migration_version }
    end

    def executed_migrations
      migrations.select { |m| m.version <= fixtures_migration_version }
    end

    def migrations
      @migrations ||= set_migrations
    end

    def set_migrations
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

    Configuration = Struct.new(:configuration_data) do
      def initialize(configuration_data)
        super
        @configuration_data = configuration_data.with_indifferent_access
      end

      def label_templates
        @configuration_data["label"] || {}
      end

      def overwrite_fixtures?
        return true unless @configuration_data.key?("overwrite")

        @configuration_data["overwrite"]
      end

      def rename_fixtures?
        @configuration_data["rename"]
      end

      def ignored_tables
        @configuration_data["ignore"].to_a || []
      end
    end

    # RSpecConfig loads RSpec configuration
    class RSpecConfig
      attr_reader :rspec_path

      def initialize(rspec_path)
        @rspec_path = rspec_path
      end

      def fixture_paths
        $LOAD_PATH.unshift(rspec_path)
        require "rspec/rails"
        require_relative rspec_path.join("rails_helper").to_s

        if RSpec.configuration.respond_to?(:fixture_paths=)
          RSpec.configuration.fixture_paths
        else
          Array(RSpec.configuration.fixture_path)
        end
      end
    end

    # MinitestConfig loads Minitest configuration
    class MinitestConfig
      attr_reader :minitest_path

      def initialize(minitest_path)
        @minitest_path = minitest_path
      end

      def fixture_paths
        # Monkey patching Minitest to avoid autorun
        Minitest.define_singleton_method(:autorun) { nil }

        require "rails/test_help"

        if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
          ActiveSupport::TestCase.fixture_paths
        else
          Array(ActiveSupport::TestCase.fixture_path)
        end
      end
    end
  end
end
