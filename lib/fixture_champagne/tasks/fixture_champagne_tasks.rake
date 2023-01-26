# frozen_string_literal: true

require "fixture_champagne"

namespace :fixture_champagne do
  desc "Run Fixture Champagne migrations to update fixtures"
  task migrate: :_load_test_environment do
    FixtureChampagne::MigrationContext.migrate
  end

  desc "Rollback Fixture Champagne last executed migration"
  task rollback: :_load_test_environment do
    FixtureChampagne::MigrationContext.rollback
  end

  # HACK: Forces the task to run in the test environment to avoid parsing development database
  # TODO: Find a better way. For now, this hack is easy to remove if the user is forced to pass the env variable
  task :_force_test_environment do
    unless Rails.env.test?
      tasks = Rake.application.top_level_tasks
      exec({ "RAILS_ENV" => "test" }, "bin/rails", *tasks)
    end
  end

  task _load_test_environment: %i[_force_test_environment environment]
end
