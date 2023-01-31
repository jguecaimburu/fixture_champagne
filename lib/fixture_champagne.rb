# frozen_string_literal: true

require_relative "fixture_champagne/version"

module FixtureChampagne
  require "fixture_champagne/railtie" if defined?(Rails)

  autoload :MigrationContext, "fixture_champagne/migration_context"
  autoload :Migrator, "fixture_champagne/migrator"
  autoload :Migration, "fixture_champagne/migration"

  class RepeatedFixtureError < StandardError; end

  class WrongFixtureLabelInterpolationError < StandardError
    def initialize(error_data = {})
      super("Missing attribute or method #{error_data[:attribute]} for record class #{error_data[:klass]}")
    end
  end

  class IllegalMigrationNameError < StandardError
    def initialize(name = nil)
      if name
        super("Illegal name for migration file: #{name}\n\t(only lower case letters, numbers, and '_' allowed).")
      else
        super("Illegal name for migration.")
      end
    end
  end
end
