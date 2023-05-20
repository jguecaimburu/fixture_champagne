# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [File.expand_path("dummy/test/fixtures", __dir__)]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
else
  # TODO: This will be removed in Rails 7.2
  ActiveSupport::TestCase.fixture_path = File.expand_path("dummy/test/fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
end

ActiveSupport::TestCase.file_fixture_path = File.expand_path("dummy/test/fixtures/files", __dir__)
ActiveSupport::TestCase.fixtures :all

require "minitest/mock"
