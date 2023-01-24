# frozen_string_literal: true

require "fixture_champagne"
require "rails/railtie"

module FixtureChampagne
  class Railtie < Rails::Railtie
    railtie_name :fixture_champagne

    rake_tasks do
      path = File.expand_path(__dir__)
      Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
    end
  end
end
