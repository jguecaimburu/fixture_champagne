# frozen_string_literal: true

require_relative "test_fixtures"

module FixtureChampagne
  # Migrator parses pre existing fixtures, executes given migrations in the given direction and regenerates fixtures.
  #
  # The migrator implements the TestFixtures module to have access to a test database with pre existing fixtures
  # already loaded and fixture accessors. It allows migrations access to all this.
  # It contains the rules on how to avoid repeated fixtures, how to handle attached files, where to put temporal
  # fixtures before overwritting (if necessary) and how to structure the fixtures folder tree.
  class Migrator
    include TestFixtures

    attr_reader :direction, :migrations, :target_migration_version, :target_schema_version, :configuration

    class << self
      def fixture_unique_id(table_name:, id:)
        "#{table_name}_#{id}"
      end

      def tmp_fixture_path
        Rails.root.join("tmp", "fixtures")
      end

      def fixture_attachment_folders
        %w[files active_storage action_text].map { |f| fixture_path.join(f) }
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
      @pre_existing_fixtures_label_mapping = pre_existing_fixture_sets.each_with_object({}) do |fixture_set, mapping|
        fixture_set.fixtures.each do |label, fixture|
          unique_id = fixture_unique_id(fixture, fixture_set)
          if mapping.key?(unique_id)
            raise RepeatedFixtureError,
                  "repeated fixture in preprocess for label #{label}, unique id #{unique_id}"
          end
          mapping[unique_id] = label.to_s
        end
      end
    end

    def run_migrations
      migrations.each { |m| m.migrate(direction: direction, migrator: self) }
    end

    def create_fixture_files_from_test_db
      klasses = fixtureable_models
      fixtures_data = build_fixture_data(klasses)
      create_new_fixture_files(klasses, fixtures_data)
    end

    # Only generate fixture files for application models that own a table to avoid several files
    # in the case of STI.
    def fixtureable_models
      descendants = ApplicationRecord.descendants
      descendants.filter(&:table_exists?).map do |descendant|
        next if configuration.ignored_tables.include?(descendant.table_name.to_s)

        table_ancestor = descendant
        table_ancestor = table_ancestor.superclass while table_ancestor.superclass.table_exists?
        table_ancestor
      end.compact.uniq
    end

    def build_fixture_data(klasses)
      data = serialize_database_records(klasses)

      data.each_with_object({}) do |(table, table_data), sorted_data|
        next if table_data.empty?

        sorted_data[table] = table_data.sort.to_h
      end
    end

    def serialize_database_records(klasses)
      klasses.each_with_object({}) do |klass, hash|
        table_name = klass.table_name.to_s
        if hash.key?(table_name)
          raise RepeatedFixtureError,
                "repeated table key for new fixtures, table #{table_name}, class: #{klass}"
        end

        hash[table_name] = serialize_table_records(klass)
      end
    end

    def serialize_table_records(klass)
      table_data = {}

      klass.all.each do |record|
        label = fixture_label(record)
        if table_data.key?(label)
          raise RepeatedFixtureError,
                "repeated fixture in serialization for label #{label}, class #{klass}"
        end

        table_data[label] = fixture_serialized_attributes(record)
      end

      table_data
    end

    # Record id is built from fixture label via ActiveRecord::FixtureSet.identify
    def fixture_unique_id(fixture, fixture_set)
      self.class.fixture_unique_id(table_name: fixture_set.table_name, id: fixture.find.id)
    end

    def fixture_label(record)
      labeler.label_for(record: record)
    end

    def labeler
      @labeler ||= Labeler.new(
        pre_existing_fixtures_labels: @pre_existing_fixtures_label_mapping,
        templates: configuration.label_templates,
        rename: configuration.rename_fixtures?
      )
    end

    def fixture_serialized_attributes(record)
      serializer.serialized_attributes_for(record: record)
    end

    def serializer
      @serializer ||= Serializer.new(labeler: labeler)
    end

    def create_new_fixture_files(klasses, fixtures_data)
      setup_temporal_fixtures_dir
      copy_fixture_attachments
      klasses.each do |klass|
        data = fixtures_data[klass.table_name]
        filename = temporal_fixture_filename(klass)
        create_temporal_fixture_file(data, filename)
      end
      return unless configuration.overwrite_fixtures?

      overwrite_fixtures
      remember_new_fixture_versions
    end

    def setup_temporal_fixtures_dir
      FileUtils.rm_r(self.class.tmp_fixture_path, secure: true) if self.class.tmp_fixture_path.exist?
      FileUtils.mkdir(self.class.tmp_fixture_path)
    end

    def copy_fixture_attachments
      self.class.fixture_attachment_folders.each do |folder|
        FileUtils.cp_r(folder, self.class.tmp_fixture_path) if folder.exist?
      end
    end

    def temporal_fixture_filename(klass)
      parts = klass.to_s.split("::").map(&:underscore)
      parts << parts.pop.pluralize.concat(".yml")
      self.class.tmp_fixture_path.join(*parts)
    end

    def create_temporal_fixture_file(data, filename)
      FileUtils.mkdir_p(filename.dirname)
      File.open(filename, "w") do |file|
        yaml = YAML.dump(data).gsub(/\n(?=[^\s])/, "\n\n").delete_prefix("---\n\n")
        file.write(yaml)
      end
    end

    def overwrite_fixtures
      removable_fixture_path = self.class.fixture_path.dirname.join("old_fixtures")
      FileUtils.mv(self.class.fixture_path, removable_fixture_path)
      FileUtils.mv(self.class.tmp_fixture_path, self.class.fixture_path)
      FileUtils.rm_r(removable_fixture_path, secure: true)
    end

    def remember_new_fixture_versions
      File.open(MigrationContext.fixture_versions_path, "w") do |file|
        yaml = YAML.dump({ "version" => target_migration_version, "schema_version" => target_schema_version })
        file.write(yaml)
      end
    end

    # Labeler decides how a fixture should be labeled based on the config file and interpolation rules.
    class Labeler
      INTERPOLATION_PATTERN = /%\{([\w|]+)\}/.freeze

      def initialize(pre_existing_fixtures_labels:, templates:, rename:)
        @pre_existing_fixtures_labels = pre_existing_fixtures_labels
        @templates = templates
        @rename = rename
      end

      def label_for(record:)
        if @rename
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
        template.gsub(INTERPOLATION_PATTERN) do
          attribute = ::Regexp.last_match(1).to_sym
          value = if record.respond_to?(attribute)
                    record.send(attribute)
                  else
                    raise WrongFixtureLabelInterpolationError, attribute: attribute, klass: record.class
                  end
          value
        end.parameterize(separator: "_")
      end
    end

    # Serializer decides how instance attributes translate to a hash, later saved as a fixture in a YAML file.
    class Serializer
      attr_reader :labeler

      def initialize(labeler:)
        @labeler = labeler
      end

      def serialized_attributes_for(record:)
        column_attributes = record.attributes.select { |a| record.class.column_names.include?(a) }

        # Favour fixtures autofilled timestamps and autogenerated ids
        filtered_attributes = %w[id created_at updated_at]

        serialized_attributes = column_attributes.map do |attribute, value|
          serialize_attribute(record, attribute, value, filtered_attributes)
        end

        serialized_attributes.sort_by(&:first).to_h.except(*filtered_attributes)
      end

      def serialize_attribute(record, attribute, value, filtered_attributes)
        belongs_to_association = record.class.reflect_on_all_associations.filter(&:belongs_to?).find do |a|
          a.foreign_key.to_s == attribute
        end
        type = record.class.type_for_attribute(attribute)

        if belongs_to_association.present?
          filter_belongs_to_columns(belongs_to_association, filtered_attributes)
          serialize_belongs_to(record, belongs_to_association)
        else
          serialize_type(record, attribute, value, type)
        end
      end

      def serialize_belongs_to(record, belongs_to_association)
        associated_record = record.send(belongs_to_association.name)

        reference_label = if belongs_to_association.polymorphic?
                            foreign_type = record.send(belongs_to_association.foreign_type)
                            "#{labeler.label_for(record: associated_record)} (#{foreign_type})"
                          else
                            labeler.label_for(record: associated_record)
                          end

        [belongs_to_association.name.to_s, reference_label]
      end

      def serialize_type(record, attribute, value, type)
        if type.type == :datetime
          # ActiveRecord::Type::DateTime#serialize returns a TimeWithZone object that makes the YAML dump less clear
          [attribute, record.read_attribute_before_type_cast(attribute)]
        elsif type.respond_to?(:serialize)
          [attribute, type.serialize(value)]
        else
          [attribute, value.to_s]
        end
      end

      def filter_belongs_to_columns(belongs_to_association, filtered_attributes)
        filtered_attributes << belongs_to_association.foreign_key.to_s
        return unless belongs_to_association.polymorphic?

        filtered_attributes << belongs_to_association.foreign_type.to_s
      end
    end
  end
end
