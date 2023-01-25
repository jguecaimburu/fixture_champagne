# frozen_string_literal: true

module FixtureChampagne
  class Migration
    MIGRATION_FILENAME_REGEXP = /\A([0-9]+)_([_a-z0-9]*)\.rb\z/.freeze

    class << self
      def new_migration_version
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end
    end

    class Base
      attr_reader :version

      def initialize(version)
        @version = version
      end

      def announce
        # TODO: Implement
      end

      def migrate
        # TODO: Implement
      end
    end

    Proxy = Struct.new(:name, :version, :filename) do
      def initialize(name, version, filename)
        super
        @migration = nil
      end

      def basename
        File.basename(filename)
      end

      delegate :migrate, :announce, to: :migration

      private

      def migration
        @migration ||= load_migration
      end

      def load_migration
        begin
          Object.send(:remove_const, name)
        rescue StandardError
          nil
        end

        load(File.expand_path(filename))
        name.constantize.new(version)
      end
    end
  end
end
