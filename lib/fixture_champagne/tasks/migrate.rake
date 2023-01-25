# frozen_string_literal: true

require "fixture_champagne/migration_context"

namespace :fixture_champagne do
  desc "Run Fixture Champagne migrations to update fixtures"
  task migrate: :load_test_environment do
    FixtureChampagne::MigrationContext.migrate
  end

  # TODO: Find a better way. For now, this hack is easy to remove if the user is forced to pass the env variable
  desc "Forces the task to run in the test environment to avoid parsing development database"
  task :force_test_environment do
    unless Rails.env.test?
      tasks = Rake.application.top_level_tasks
      exec({ "RAILS_ENV" => "test" }, "bin/rails", *tasks)
    end
  end

  task load_test_environment: %i[force_test_environment environment]
end
