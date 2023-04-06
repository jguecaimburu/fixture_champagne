# frozen_string_literal: true

module FixtureChampagne
  # TestFixtures allows access to a test database with fixtures preloaded and all fixture accessors.
  #
  # TestFixtures calls the ActiveRecord::TestDatabases to regenerate a test db and adapts the
  # ActiveRecord::TestFixtures module to parse all pre existing fixtures and generate the required
  # accessors.
  module TestFixtures
    extend ActiveSupport::Concern
    include ActiveRecord::TestFixtures

    included do
      if respond_to?(:fixture_paths)
        fixture_paths << MigrationContext.fixture_paths
      else
        self.fixture_path = MigrationContext.fixture_paths.first
      end
      fixtures :all
    end

    class_methods do
      # FIXME: Should implement a strategy to regenerate different fixture folders
      def single_fixture_path
        if respond_to?(:fixture_paths)
          fixture_paths.first
        else
          fixture_path
        end
      end
    end

    def name
      self.class.name
    end

    def before_migrate
      setup_fixtures
    end

    def after_migrate
      teardown_fixtures
    end

    def pre_existing_fixtures
      @loaded_fixtures
    end

    def pre_existing_fixture_sets
      pre_existing_fixtures.map { |_k, v| v }
    end

    def pre_existing_fixture_accessors
      # fixture_sets implementation: https://github.com/rails/rails/commit/05d80fc24f03ca5310931eacefdc247a393dd861
      # Still not released
      return fixture_sets.keys if respond_to?(:fixture_sets) && fixture_sets.keys.any?

      fixture_table_names.map do |t_name|
        t_name.to_s.include?("/") ? t_name.to_s.tr("/", "_") : t_name.to_s
      end
    end
  end
end
