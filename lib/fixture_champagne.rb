# frozen_string_literal: true

require_relative "fixture_champagne/version"

module FixtureChampagne
  require "fixture_champagne/railtie" if defined?(Rails)

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
