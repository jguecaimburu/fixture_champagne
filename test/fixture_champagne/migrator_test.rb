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
    Dir.glob("#{FixtureChampagne::Migrator::TMP_FIXTURE_PATH}/**/*.yml").each_with_object({}) do |path, mapping|
      key = path.scan(%r{.*/fixtures/(.*)\.yml}).first.first
      mapping[key] = {}
      ActiveRecord::FixtureSet::File.open(path).each { |row| mapping[key][row.first] = row.last }
    end
  end

  def remove_temporary_fixture_folder
    FileUtils.rm_rf(FixtureChampagne::Migrator::TMP_FIXTURE_PATH)
  end

  setup do
    remove_temporary_fixture_folder
    @current_version = FixtureChampagne::MigrationContext.fixture_versions["version"]
    @available_migrations = [
      AddUnlockedHardLevel.new(@current_version + 10),
      WeaponizeGreenie.new(@current_version + 20)
    ]
  end

  teardown { remove_temporary_fixture_folder }

  test "tmp_fixture_path" do
    assert_equal(FixtureChampagne::Migrator::TMP_FIXTURE_PATH, Rails.root.join("tmp", "fixtures"))
  end

  test "fixture_attachment_folders" do
    migrator = FixtureChampagne::Migrator.new(
      direction: :up,
      migrations: @available_migrations,
      target_migration_version: @available_migrations.map(&:version).max,
      target_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: FixtureChampagne::MigrationContext::Configuration.new(overwrite: false)
    )

    attachment_folders = migrator.fixture_attachment_folders

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

    # Right files and fixture set sizes

    assert_equal(3, new_fixtures_data["levels"].size)
    assert_equal(3, new_fixtures_data["character/turtles"].size)
    assert_equal(1, new_fixtures_data["character/mushrooms"].size)
    assert_equal(2, new_fixtures_data["weaponizable/weapons"].size)
    assert_equal(1, new_fixtures_data["active_storage/blobs"].size)
    assert_equal(1, new_fixtures_data["active_storage/attachments"].size)

    # New fixtures have default labels

    new_levels = new_fixtures_data["levels"].filter { |k, _v| /levels_[1-9]+/.match?(k) }

    assert_equal(1, new_levels.size)

    new_level = new_levels.first.last

    # Old fixture labels are the same

    other_levels = new_fixtures_data["levels"].reject { |k, _v| new_levels.map(&:first).include?(k) }

    assert_equal(%w[easy hard], other_levels.map(&:first).sort)

    # Attachment files were not changed

    old_files = Dir.glob(Rails.root.join("test", "fixtures", "files")).map { |p| File.basename(p) }.sort
    new_files = Dir.glob(Rails.root.join("tmp", "fixtures", "files")).map { |p| File.basename(p) }.sort

    assert_equal(old_files, new_files)

    blob = new_fixtures_data["active_storage/blobs"]["mushy_pic"]

    assert_equal(1_261_900, blob["byte_size"])
    assert_equal("mushroom.png", blob["filename"])

    attachment = new_fixtures_data["active_storage/attachments"]["mushy_pic"]

    assert_equal("mushy_pic", attachment["blob"])
    assert_equal("mushy (Character::Mushroom)", attachment["record"])

    # Polymorphic belongs_to and types are serialized properly

    new_weapons = new_fixtures_data["weaponizable/weapons"].select { |k, _v| /weaponizable_weapons_[1-9]+/.match?(k) }

    assert_equal(1, new_weapons.size)

    new_weapon = new_weapons.first.last

    assert_equal("Weaponizable::Weapon::Rocket", new_weapon["type"])
    assert_equal("greenie (Character::Turtle)", new_weapon["weaponizable"])

    # Regular belongs_to are serialized properly

    greenie_turtle = new_fixtures_data["character/turtles"]["greenie"]

    assert_equal("easy", greenie_turtle["level"])

    # Encrypted attributes

    mushy = new_fixtures_data["character/mushrooms"]["mushy"]

    assert_equal("hongo_trendy", mushy["code_name"])

    # Other types

    greenie_history = "I don't have a long history but sometimes I like \
to speak for a while just to make people comfortable"

    assert_equal(greenie_turtle["history"], greenie_history)
    assert_equal(greenie_turtle["birthday"], Date.new(2019, 12, 10))
    assert_equal("hard", new_level["difficulty"])
    assert(new_level["unlocked"])
    assert_in_delta(new_weapon["precision"], 0.15)
    assert_equal(120, new_weapon["power"])
    assert_equal("2018-12-09 22:30:00", mushy["collection_time"])
  end

  test "migrate without pending migrations" do
    migrator = FixtureChampagne::Migrator.new(
      direction: :up,
      migrations: [],
      target_migration_version: @current_version,
      target_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: FixtureChampagne::MigrationContext::Configuration.new(overwrite: false)
    )

    migrator.migrate

    new_fixtures_data = parse_temporary_fixture_folder

    assert_equal(2, new_fixtures_data["levels"].size)
    assert_equal(3, new_fixtures_data["character/turtles"].size)
    assert_equal(1, new_fixtures_data["character/mushrooms"].size)
    assert_equal(1, new_fixtures_data["weaponizable/weapons"].size)
    assert_equal(1, new_fixtures_data["active_storage/blobs"].size)
    assert_equal(1, new_fixtures_data["active_storage/attachments"].size)
  end

  test "migrate with specific label templates and rename false" do
    config = FixtureChampagne::MigrationContext::Configuration.new(
      overwrite: false,
      rename: false,
      label: { "levels" => "new_%{difficulty}" }
    )
    migrator = FixtureChampagne::Migrator.new(
      direction: :up,
      migrations: @available_migrations,
      target_migration_version: @available_migrations.map(&:version).max,
      target_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: config
    )

    migrator.migrate

    new_fixtures_data = parse_temporary_fixture_folder

    # Right files and fixture set sizes

    assert_equal(3, new_fixtures_data["levels"].size)
    assert_equal(3, new_fixtures_data["character/turtles"].size)
    assert_equal(1, new_fixtures_data["character/mushrooms"].size)
    assert_equal(2, new_fixtures_data["weaponizable/weapons"].size)
    assert_equal(1, new_fixtures_data["active_storage/blobs"].size)
    assert_equal(1, new_fixtures_data["active_storage/attachments"].size)

    # Old fixtures kept labels, new fixtures use template

    assert_equal(%w[easy hard new_hard], new_fixtures_data["levels"].keys.sort)
  end

  test "migrate with specific label templates and rename true" do
    config = FixtureChampagne::MigrationContext::Configuration.new(
      overwrite: false,
      rename: true,
      label: { "levels" => "%{name}_%{difficulty}" }
    )
    migrator = FixtureChampagne::Migrator.new(
      direction: :up,
      migrations: @available_migrations,
      target_migration_version: @available_migrations.map(&:version).max,
      target_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: config
    )

    migrator.migrate

    new_fixtures_data = parse_temporary_fixture_folder

    # Right files and fixture set sizes

    assert_equal(3, new_fixtures_data["levels"].size)
    assert_equal(3, new_fixtures_data["character/turtles"].size)
    assert_equal(1, new_fixtures_data["character/mushrooms"].size)
    assert_equal(2, new_fixtures_data["weaponizable/weapons"].size)
    assert_equal(1, new_fixtures_data["active_storage/blobs"].size)
    assert_equal(1, new_fixtures_data["active_storage/attachments"].size)

    # Old fixtures kept labels, new fixtures use template

    assert_equal(%w[final_hard initial_easy unlocked_hard], new_fixtures_data["levels"].keys.sort)
  end

  test "migrate with ignored tables" do
    config = FixtureChampagne::MigrationContext::Configuration.new(
      overwrite: false,
      ignore: ["weaponizable_weapons"]
    )
    migrator = FixtureChampagne::Migrator.new(
      direction: :up,
      migrations: [],
      target_migration_version: @current_version,
      target_schema_version: FixtureChampagne::MigrationContext.schema_current_version,
      configuration: config
    )

    migrator.migrate

    new_fixtures_data = parse_temporary_fixture_folder

    # Right files and fixture set sizes

    assert_equal(2, new_fixtures_data["levels"].size)
    assert_equal(3, new_fixtures_data["character/turtles"].size)
    assert_equal(1, new_fixtures_data["character/mushrooms"].size)
    assert_equal(1, new_fixtures_data["active_storage/blobs"].size)
    assert_equal(1, new_fixtures_data["active_storage/attachments"].size)

    assert_nil(new_fixtures_data["weaponizable/weapons"])
  end
end
