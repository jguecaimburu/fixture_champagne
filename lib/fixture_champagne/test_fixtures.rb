# frozen_string_literal: true

# frozen_string_literal

module FixtureChampagne
  module TestFixtures
    extend ActiveSupport::Concern
    include ActiveRecord::TestFixtures

    included do
      self.fixture_path = MigrationContext.fixtures_path
      fixtures :all
    end

    def name
      self.class.name
    end

    def before_migrate
      ActiveRecord::TestDatabases.create_and_load_schema(0, env_name: "test")
      setup_fixtures
    end

    def after_migrate
      teardown_fixtures
    end

    def pre_existing_fixtures
      @loaded_fixtures
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
