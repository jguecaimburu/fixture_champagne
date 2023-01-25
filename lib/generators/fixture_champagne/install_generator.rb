# frozen_string_literal: true

require "rails/generators/base"

module FixtureChampagne
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Setup fixture_champagne required files and folders."

      def create_migrations_folder
        return if FixtureChampagne::MigrationContext.expected_fixture_migrations_path.exist?

        empty_directory FixtureChampagne::MigrationContext.expected_fixture_migrations_path
      end
    end
  end
end
