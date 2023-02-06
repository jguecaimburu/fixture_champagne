# frozen_string_literal: true

require "test_helper"

class MigratorTest < ActiveSupport::TestCase
  setup do
    remove_temporary_fixture_folder
    @available_migrations = []
  end

  teardown { remove_temporary_fixture_folder }

  test "migrate without pending migrations" do
  end

  test "migrate pending migrations with default config" do
  end

  test "migrate with specific label templates" do
  end

  test "ignore tables in migration" do
  end

  test "rename fixtures" do
  end
end
