# frozen_string_literal: true

require "test_helper"

class MigratorTest < ActiveSupport::TestCase
  class AddUnlockedHardLevel < FixtureChampagne::Migration::Base
    def up
      Level.create!(name: "Unlocked", difficulty: :hard, unlocked: true)
    end

    def down
      Level.find_by(name: "Unlocked").destroy!
    end
  end

  class WeaponizeGreenie < FixtureChampagne::Migration::Base
    def up
      Weaponizable::Weapon::Rocket.create!(power: 120, precision: 0.15, weaponizable: character_turtles(:greenie))
    end

    def down
      Weaponizable::Weapon::Rocket.find_by(weaponizable: character_turtles(:greenie), power: 120).destroy!
    end
  end

  # FIXME: This logic might find a better place elsewhere. For now, it's only used here as parsing
  #        fixture files without initializing records is not required in any other process
  def parse_temporary_fixture_folder
    Dir.glob("#{FixtureChampagne::Migrator.tmp_fixture_path}/**/*.yml").each_with_object({}) do |path, mapping|
      key = path.scan(%r{.*/fixtures/(.*)\.yml}).first.first.gsub("/", "_")
      mapping[key] = {}
      ActiveRecord::FixtureSet::File.open(path).each { |row| mapping[key][row.first] = row.last }
    end
  end

  def remove_temporary_fixture_folder
    FileUtils.rm_rf(FixtureChampagne::Migrator.tmp_fixture_path)
  end

  setup do
    remove_temporary_fixture_folder
    current_version = FixtureChampagne::MigrationContext.fixture_versions["version"]
    @available_migrations = [
      AddUnlockedHardLevel.new(current_version + 10),
      WeaponizeGreenie.new(current_version + 20)
    ]
  end

  teardown { remove_temporary_fixture_folder }

  test "tmp_fixture_path" do
    assert_equal(FixtureChampagne::Migrator.tmp_fixture_path, Rails.root.join("tmp", "fixtures"))
  end

  test "fixture_attachment_folders" do
    attachment_folders = FixtureChampagne::Migrator.fixture_attachment_folders

    assert_includes(attachment_folders, Rails.root.join("test", "fixtures", "files"))
    assert_includes(attachment_folders, Rails.root.join("test", "fixtures", "active_storage"))
    assert_includes(attachment_folders, Rails.root.join("test", "fixtures", "action_text"))
  end

  test "migrate generates the right files" do
    migrator = FixtureChampagne::Migrator.new(
      direction: :up,
      migrations: @available_migrations,
      target_migration_version: @available_migrations.map(&:version).max,
      target_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: FixtureChampagne::MigrationContext::Configuration.new(overwrite: false)
    )

    migrator.migrate

    new_fixtures_data = parse_temporary_fixture_folder

    # Make better assertions
    refute_nil new_fixtures_data
  end

  # test "migrate without pending migrations" do
  # end

  # test "migrate with specific label templates" do
  # end

  # test "ignore tables in migration" do
  # end

  # test "rename fixtures" do
  # end
end
