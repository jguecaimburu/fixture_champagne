# frozen_string_literal: true

require "test_helper"

class MigrationContextTest < ActiveSupport::TestCase
  class RaisingMigrator
    def initialize(**kwargs)
      @attributes = kwargs
    end

    def migrate
      case @attributes[:direction]
      when :up
        raise "unexpected migrate with direction up"
      when :down
        raise "unexpected migrate with direction down"
      else
        raise "unexpected migrate with unidentified direction #{@attributes[:direction]}"
      end
    end
  end

  test "fixture_migrations_path" do
    assert_equal(FixtureChampagne::MigrationContext.fixture_migrations_path,
                 Rails.root.join("test", "fixture_migrations"))
  end

  test "fixture_path" do
    assert_equal(FixtureChampagne::MigrationContext.fixtures_path, Rails.root.join("test", "fixtures"))
  end

  test "configuration_path" do
    assert_equal(FixtureChampagne::MigrationContext.configuration_path,
                 Rails.root.join("test", "fixture_champagne.yml"))
  end

  test "fixture_versions_path" do
    assert_equal(FixtureChampagne::MigrationContext.fixture_versions_path,
                 Rails.root.join("test", ".fixture_champagne_versions.yml"))
  end

  test "up_target_fixture_migration_version" do
    context = FixtureChampagne::MigrationContext.build_context

    assert_equal(20_230_206_135_442, context.up_target_fixture_migration_version)
  end

  test "down_target_fixture_migration_version if only one migration was executed" do
    context = FixtureChampagne::MigrationContext.build_context

    assert_equal(0, context.down_target_fixture_migration_version)
  end

  test "down_target_fixture_migration_version if more than one migration was executed" do
    context = FixtureChampagne::MigrationContext.new(
      fixture_migrations_path: FixtureChampagne::MigrationContext.fixture_migrations_path,
      schema_current_version: FixtureChampagne::MigrationContext.schema_current_version,
      fixtures_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: FixtureChampagne::MigrationContext.configuration,
      fixtures_migration_version: 20_230_206_135_442
    )

    assert_equal(20_230_206_133_547, context.down_target_fixture_migration_version)
  end

  test "pending_migrations" do
    context = FixtureChampagne::MigrationContext.build_context
    pending_migrations = context.pending_migrations

    assert_equal(1, pending_migrations.size)
    assert_equal(20_230_206_135_442, pending_migrations.first.version)
  end

  test "executed_migrations" do
    context = FixtureChampagne::MigrationContext.build_context
    executed_migrations = context.executed_migrations

    assert_equal(1, executed_migrations.size)
    assert_equal(20_230_206_133_547, executed_migrations.first.version)
  end

  test "migrate calls migrator if any pending migration" do
    migrator = Minitest::Mock.new
    migrator.expect :migrate, nil
    context = FixtureChampagne::MigrationContext.build_context

    assert_migrator_args = ->(**kwargs) { assert_equal(:up, kwargs[:direction]) && migrator }

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
      fixtures_migration_version: 20_230_206_135_442
    )

    assert_migrator_args = ->(**kwargs) { assert_equal(:up, kwargs[:direction]) && migrator }

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
      fixtures_migration_version: 20_230_206_135_442
    )

    assert_migrator_args = ->(**kwargs) { assert_equal(:up, kwargs[:direction]) && migrator }

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
      fixtures_migration_version: 20_230_206_135_442
    )

    out, err = capture_io do
      FixtureChampagne::Migrator.stub(:new, ->(**kwargs) { RaisingMigrator.new(**kwargs) }) do
        context.migrate
      end
    end

    assert_equal("No fixture migrations pending.\n", out)
    assert_equal("", err)
  end

  test "rollback calls migrator if any executed migration" do
    migrator = Minitest::Mock.new
    migrator.expect(:migrate, nil)
    context = FixtureChampagne::MigrationContext.build_context

    assert_migrator_args = ->(**kwargs) { assert_equal(:down, kwargs[:direction]) && migrator }

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

    out, err = capture_io do
      FixtureChampagne::Migrator.stub(:new, ->(**kwargs) { RaisingMigrator.new(**kwargs) }) do
        context.rollback
      end
    end

    assert_equal("No migration to rollback.\n", out)
    assert_equal("", err)
  end
end
