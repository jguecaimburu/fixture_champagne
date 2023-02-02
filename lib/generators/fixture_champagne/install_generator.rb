# frozen_string_literal: true

module FixtureChampagne
  module Generators
    # InstallGenerator generates a the boilerplate necessary to use the gem.
    #
    # From your app directory you can run:
    # bin/rails generate fixture_champagne:install
    #
    # This will create the folder set at FixtureChampagne::MigrationContext.fixture_migrations_path
    # if it does not already exist.
    class InstallGenerator < Rails::Generators::Base
      desc "Setup fixture_champagne required files and folders."

      def create_migrations_folder
        return if FixtureChampagne::MigrationContext.expected_fixture_migrations_path.exist?

        empty_directory FixtureChampagne::MigrationContext.expected_fixture_migrations_path
      end
    end
  end
end
