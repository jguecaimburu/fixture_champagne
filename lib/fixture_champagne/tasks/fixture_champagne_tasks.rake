# frozen_string_literal: true

require "fixture_champagne"

namespace :fixture_champagne do
  desc "Run Fixture Champagne migrations to update fixtures"
  task migrate: :environment  do
    FixtureChampagne::MigrationContext.migrate
  end

  desc "Rollback Fixture Champagne last executed migration"
  task rollback: :environment do
    FixtureChampagne::MigrationContext.rollback
  end
end
