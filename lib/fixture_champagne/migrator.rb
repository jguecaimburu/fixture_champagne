# frozen_string_literal: true

require_relative "test_fixtures"

module FixtureChampagne
  class Migrator
    include TestFixtures

    attr_reader :direction, :migrations, :target_migration_version, :target_schema_version, :configuration

    class << self
      def fixture_unique_id(table_name:, id:)
        "#{table_name}_#{id}"
      end
    end

    def initialize(
      direction:, migrations:,
      target_migration_version:, target_schema_version:, configuration:
    )
      @direction = direction
      @migrations = migrations
      @target_migration_version = target_migration_version
      @target_schema_version = target_schema_version
      @configuration = configuration
    end

    def migrate
      before_migrate

      process_pre_existing_fixtures
      run_migrations
      create_fixture_files_from_test_db

      after_migrate
    end

    def process_pre_existing_fixtures
      fixture_sets = pre_existing_fixtures.map { |_k, v| v }
      @pre_existing_fixtures_label_mapping = fixture_sets.each_with_object({}) do |fixture_set, mapping|
        fixture_set.fixtures.each do |label, fixture|
          unique_id = fixture_unique_id(fixture, fixture_set)
          raise "repeated fixture for label #{label}, unique id #{unique_id}" if mapping.key?(unique_id)

          mapping[unique_id] = label.to_s
        end
      end
    end

    def run_migrations
      migrations.each { |m| m.migrate(direction: direction, migrator: self) }
    end

    def create_fixture_files_from_test_db
      new_fixtures = fixtureable_models.each_with_object({}) do |klass, hash|
        table_name = klass.table_name.to_s
        raise "repeated table key for new fixtures, table #{table_name}, class: #{klass}" if hash.key?(table_name)

        hash[table_name] = {}

        klass.all.each do |record|
          label = fixture_label(record)
          raise "repeated fixture for label #{label}, class #{klass}" if hash[table_name].key?(label)

          hash[table_name][label] = fixture_serialized_attributes(record)
        end
      end
    end

    # Record id is built from fixture label via ActiveRecord::FixtureSet.identify
    def fixture_unique_id(fixture, fixture_set)
      self.class.fixture_unique_id(table_name: fixture_set.table_name, id: fixture.find.id)
    end

    def fixtureable_models
      descendants = ApplicationRecord.descendants
      descendants.filter(&:table_exists?).map do |descendant|
        table_ancestor = descendant
        table_ancestor = table_ancestor.superclass while table_ancestor.superclass.table_exists?
        table_ancestor
      end.uniq
    end

    def fixture_label(record)
      labeler.label_for(record: record)
    end

    def labeler
      @labeler ||= Labeler.new(
        pre_existing_fixtures_labels: @pre_existing_fixtures_label_mapping,
        templates: configuration.label_templates,
        overwrite: configuration.overwrite_current_labels?
      )
    end

    def fixture_serialized_attributes(record)
      serializer.serialized_attributes_for(record: record)
    end

    def serializer
      @serializer ||= Serializer.new(labeler: labeler)
    end

    class Labeler
      INTERPOLATION_PATTERN = /%\{([\w|]+)\}/.freeze

      def initialize(pre_existing_fixtures_labels:, templates:, overwrite:)
        @pre_existing_fixtures_labels = pre_existing_fixtures_labels
        @templates = templates
        @overwrite = overwrite
      end

      def label_for(record:)
        if @overwrite
          build_label_for(record)
        else
          find_label_for(record) || build_label_for(record)
        end
      end

      private

      def find_label_for(record)
        @pre_existing_fixtures_labels[record_unique_id(record)]
      end

      def build_label_for(record)
        template = @templates[record.class.table_name]

        if template.nil? || template == "DEFAULT"
          default_label(record)
        else
          interpolate_template(template, record)
        end
      end

      def default_label(record)
        record_unique_id(record)
      end

      def record_unique_id(record)
        Migrator.fixture_unique_id(table_name: record.class.table_name, id: record.id)
      end

      def interpolate_template(template, record)
        template.gsub(INTERPOLATION_PATTERN) do |_match|
          attribute = ::Regexp.last_match(1).to_sym
          value = if record.responds_to?(attribute)
                    record.send(attribute)
                  else
                    raise "Missing attribute #{attribute} for record class #{record.class}"
                  end
          value
        end
      end
    end

    class Serializer
      attr_reader :labeler

      def initialize(labeler:)
        @labeler = labeler
      end

      def serialized_attributes_for(record:)
        klass = record.class
        attributes = record.attributes
        column_attributes = attributes.select { |a| klass.column_names.include?(a) }
        filtered_attributes = %w[id created_at updated_at]

        serialized_attributes = column_attributes.map do |attribute, value|
          belongs_to_association = klass.reflect_on_all_associations.filter(&:belongs_to?).find do |a|
            a.foreign_key.to_s == attribute
          end
          type = klass.type_for_attribute(attribute)

          if belongs_to_association&.polymorphic?
            filtered_attributes << belongs_to_association.foreign_key.to_s
            filtered_attributes << belongs_to_association.foreign_type.to_s
            foreign_type = record.send(belongs_to_association.foreign_type)
            associated_record = record.send(belongs_to_association.name)
            [belongs_to_association.name, "#{labeler.label_for(record: associated_record)} (#{foreign_type})"]
          elsif belongs_to_association
            filtered_attributes << belongs_to_association.foreign_key.to_s
            associated_record = record.send(belongs_to_association.name)
            [belongs_to_association.name, labeler.label_for(record: associated_record)]
          elsif type.respond_to?(:serialize)
            [attribute, type.serialize(value)]
          else
            [attribute, type.to_s]
          end
        end

        serialized_attributes.to_h.except(*filtered_attributes)
      end
    end
  end
end
