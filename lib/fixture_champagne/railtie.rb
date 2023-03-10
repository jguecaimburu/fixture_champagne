# frozen_string_literal: true

module FixtureChampagne
  class Railtie < Rails::Railtie # :nodoc:
    railtie_name :fixture_champagne

    rake_tasks do
      path = File.expand_path(__dir__)
      Dir.glob("#{path}/../tasks/**/*.rake").each { |f| load f }
    end
  end
end
