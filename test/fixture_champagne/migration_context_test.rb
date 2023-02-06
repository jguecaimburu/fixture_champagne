# frozen_string_literal: true

require "test_helper"

class MigrationContextTest < ActiveSupport::TestCase
  teardown { remove_temporary_fixture_folder }
  
  test "fixture_migrations_path" do
    assert_equal(FixtureChampagne::MigrationContext.fixture_migrations_path, Rails.root.join("test", "fixture_migrations"))
  end

  test "fixture_path" do
    assert_equal(FixtureChampagne::MigrationContext.fixtures_path, Rails.root.join("test", "fixtures"))
  end

  test "configuration_path" do
    assert_equal(FixtureChampagne::MigrationContext.configuration_path, Rails.root.join("test", "fixture_champagne.yml"))
  end

  test "fixture_versions_path" do
    assert_equal(FixtureChampagne::MigrationContext.fixture_versions_path, Rails.root.join("test", ".fixture_champagne_versions.yml"))
  end

  test "up_target_fixture_migration_version" do
    context = FixtureChampagne::MigrationContext.build_context
    assert_equal(context.up_target_fixture_migration_version, 20230206135442)
  end

  test "down_target_fixture_migration_version if only one migration was executed" do
    context = FixtureChampagne::MigrationContext.build_context
    assert_equal(context.down_target_fixture_migration_version, 0)
  end

  test "down_target_fixture_migration_version if more than one migration was executed" do
    context = FixtureChampagne::MigrationContext.new(
      fixture_migrations_path: FixtureChampagne::MigrationContext.fixture_migrations_path,
      schema_current_version: FixtureChampagne::MigrationContext.schema_current_version,
      fixtures_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: FixtureChampagne::MigrationContext.configuration,
      fixtures_migration_version: 20230206135442
    )
    assert_equal(context.down_target_fixture_migration_version, 20230206133547)
  end

  test "pending_migrations" do
    context = FixtureChampagne::MigrationContext.build_context
    pending_migrations = context.pending_migrations
    assert_equal(pending_migrations.size, 1)
    assert_equal(pending_migrations.first.version, 20230206135442)
  end

  test "executed_migrations" do
    context = FixtureChampagne::MigrationContext.build_context
    executed_migrations = context.executed_migrations
    assert_equal(executed_migrations.size, 1)
    assert_equal(executed_migrations.first.version, 20230206133547)
  end

  test "migrate calls migrator if any pending migration" do
    migrator = Minitest::Mock.new
    migrator.expect :migrate, nil
    context = FixtureChampagne::MigrationContext.build_context

    assert_migrator_args = ->(**kwargs) { assert_equal(kwargs[:direction], :up) && migrator }
    
    FixtureChampagne::Migrator.stub :new, assert_migrator_args do
      context.migrate
    end

    migrator.verify
  end

  test "migrate calls migrator if schema changed" do
    migrator = Minitest::Mock.new
    migrator.expect :migrate, nil
    
    context = FixtureChampagne::MigrationContext.new(
      fixture_migrations_path: FixtureChampagne::MigrationContext.fixture_migrations_path,
      schema_current_version: FixtureChampagne::MigrationContext.schema_current_version + 1,
      fixtures_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: FixtureChampagne::MigrationContext::Configuration.new({}),
      fixtures_migration_version: 20230206135442
    )

    assert_migrator_args = ->(**kwargs) { assert_equal(kwargs[:direction], :up) && migrator }

    FixtureChampagne::Migrator.stub :new, assert_migrator_args do
      context.migrate
    end

    migrator.verify
  end

  test "migrate calls migrator if renaming" do
    migrator = Minitest::Mock.new
    migrator.expect :migrate, nil
    
    context = FixtureChampagne::MigrationContext.new(
      fixture_migrations_path: FixtureChampagne::MigrationContext.fixture_migrations_path,
      schema_current_version: FixtureChampagne::MigrationContext.schema_current_version,
      fixtures_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: FixtureChampagne::MigrationContext::Configuration.new({ rename: true }),
      fixtures_migration_version: 20230206135442
    )

    assert_migrator_args = ->(**kwargs) { assert_equal(kwargs[:direction], :up) && migrator }

    FixtureChampagne::Migrator.stub :new, assert_migrator_args do
      context.migrate
    end

    migrator.verify
  end

  test "migrate does not call migrator if no pending change" do
    context = FixtureChampagne::MigrationContext.new(
      fixture_migrations_path: FixtureChampagne::MigrationContext.fixture_migrations_path,
      schema_current_version: FixtureChampagne::MigrationContext.schema_current_version,
      fixtures_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: FixtureChampagne::MigrationContext::Configuration.new({}),
      fixtures_migration_version: 20230206135442
    )

    FixtureChampagne::Migrator.stub(:new, ->(**kwargs) { RaisingMigrator.new(**kwargs) }) do
      context.migrate
    end
  end

  test "rollback calls migrator if any executed migration" do
    migrator = Minitest::Mock.new
    migrator.expect(:migrate, nil)
    context = FixtureChampagne::MigrationContext.build_context

    assert_migrator_args = ->(**kwargs) { assert_equal(kwargs[:direction], :down) && migrator }

    FixtureChampagne::Migrator.stub :new, assert_migrator_args do
      context.rollback
    end

    migrator.verify
  end

  test "rollback does not call migrator if no executed migration" do
    context = FixtureChampagne::MigrationContext.new(
      fixture_migrations_path: FixtureChampagne::MigrationContext.fixture_migrations_path,
      schema_current_version: FixtureChampagne::MigrationContext.schema_current_version,
      fixtures_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: FixtureChampagne::MigrationContext::Configuration.new({}),
      fixtures_migration_version: 0
    )

    FixtureChampagne::Migrator.stub(:new, ->(**kwargs) { RaisingMigrator.new(**kwargs) }) do
      context.rollback
    end
  end

  class RaisingMigrator
    def initialize(**kwargs)
      @attributes = kwargs
    end

    def migrate
      if @attributes[:direction] == :up
        raise "unexpected migrate with direction up"
      elsif @attributes[:direction] == :down
        raise "unexpected migrate with direction down"
      else
        raise "unexpected migrate with unidentified direction #{@attributes[:direction]}"
      end
    end
  end
end
