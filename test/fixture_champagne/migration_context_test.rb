# frozen_string_literal: true

require "test_helper"

class FixtureChampagneTest < ActiveSupport::TestCase
  setup { remove_temporary_fixture_folder }

  teardown { remove_temporary_fixture_folder }

  test "it creates a temporary fixture folder" do
    refute_predicate FixtureChampagne::Migrator.tmp_fixture_path, :exist?
    FixtureChampagne::MigrationContext.migrate

    assert_predicate FixtureChampagne::Migrator.tmp_fixture_path, :exist?
  end

  def remove_temporary_fixture_folder
    FileUtils.rm_rf(FixtureChampagne::Migrator.tmp_fixture_path)
  end
end
