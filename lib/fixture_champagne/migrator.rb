# frozen_string_literal: true

require_relative "test_fixtures"

module FixtureChampagne
  # Migrator parses pre existing fixtures, executes given migrations in the given direction and regenerates fixtures.
  #
  # The migrator implements the TestFixtures module to have access to a test database with pre existing fixtures
  # already loaded and fixture accessors. It allows migrations access to all this.
  # It contains the rules on how to avoid repeated fixtures, how to handle attached files, where to put temporary
  # fixtures before overwritting (if necessary) and how to structure the fixtures folder tree.
  class Migrator
    include TestFixtures

    attr_reader :direction, :migrations, :target_migration_version, :target_schema_version, :configuration

    TMP_FIXTURE_PATH = Rails.root.join("tmp", "fixtures")

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
      data = serialize_database_model_instances(klasses)

      data.each_with_object({}) do |(table, table_data), sorted_data|
        next if table_data.empty?

        sorted_data[table] = table_data.sort.to_h
      end
    end

    def serialize_database_model_instances(klasses)
      klasses.each_with_object({}) do |klass, hash|
        table_name = klass.table_name.to_s
        if hash.key?(table_name)
          raise RepeatedFixtureError,
                "repeated table key for new fixtures, table #{table_name}, class: #{klass}"
        end

        hash[table_name] = serialize_table_model_instances(klass)
      end
    end

    def serialize_table_model_instances(klass)
      table_data = {}

      klass.all.each do |model_instance|
        label = fixture_label(model_instance)
        if table_data.key?(label)
          raise RepeatedFixtureError,
                "repeated fixture in serialization for label #{label}, class #{klass}"
        end

        table_data[label] = fixture_serialized_attributes(model_instance)
      end

      table_data
    end

    # Record id is built from fixture label via ActiveRecord::FixtureSet.identify
    def fixture_unique_id(fixture, fixture_set)
      self.class.fixture_unique_id(table_name: fixture_set.table_name, id: fixture.find.id)
    end

    def fixture_label(model_instance)
      labeler.label_for(model_instance: model_instance)
    end

    def labeler
      @labeler ||= Labeler.new(
        pre_existing_fixtures_labels: @pre_existing_fixtures_label_mapping,
        templates: configuration.label_templates,
        rename: configuration.rename_fixtures?
      )
    end

    def fixture_serialized_attributes(model_instance)
      serializer.serialized_attributes_for(model_instance: model_instance)
    end

    def serializer
      @serializer ||= Serializer.new(labeler: labeler)
    end

    def create_new_fixture_files(klasses, fixtures_data)
      setup_temporary_fixtures_dir
      copy_fixture_attachments
      klasses.each do |klass|
        data = fixtures_data[klass.table_name]
        filename = temporary_fixture_filename(klass)
        create_temporary_fixture_file(data, filename)
      end
      return unless configuration.overwrite_fixtures?

      overwrite_fixtures
      remember_new_fixture_versions
    end

    def setup_temporary_fixtures_dir
      FileUtils.rm_r(TMP_FIXTURE_PATH, secure: true) if TMP_FIXTURE_PATH.exist?
      FileUtils.mkdir(TMP_FIXTURE_PATH)
    end

    def copy_fixture_attachments
      fixture_attachment_folders.each do |folder|
        FileUtils.cp_r(folder, TMP_FIXTURE_PATH) if folder.exist?
      end
    end

    def fixture_attachment_folders
      %w[files active_storage action_text].map { |f| effective_fixture_path.join(f) }
    end

    def temporary_fixture_filename(klass)
      parts = klass.to_s.split("::").map(&:underscore)
      parts << parts.pop.pluralize.concat(".yml")
      TMP_FIXTURE_PATH.join(*parts)
    end

    def create_temporary_fixture_file(data, filename)
      FileUtils.mkdir_p(filename.dirname)
      File.open(filename, "w") do |file|
        yaml = YAML.dump(data).gsub(/\n(?=[^\s])/, "\n\n").delete_prefix("---\n\n")
        file.write(yaml)
      end
    end

    def overwrite_fixtures
      removable_fixture_path = effective_fixture_path.dirname.join("old_fixtures")
      FileUtils.mv(effective_fixture_path, removable_fixture_path)
      FileUtils.mv(TMP_FIXTURE_PATH, effective_fixture_path)
      FileUtils.rm_r(removable_fixture_path, secure: true)
    end

    def effective_fixture_path
      @effective_fixture_path ||= set_effective_fixture_path
    end

    def set_effective_fixture_path
      # From Rails 7.1 users can set multiple fixture paths, the default being test/fixtures.
      # Most users will use the default path. Others may use a custom path but keep the default in the array,
      # even if they do not use it. For now the gem supports only these 2 cases.
      # If a user has fixture files in multiple paths, then it's trickier to decide where to save the new
      # generated fixtures, so for now the gem will not allow these users to overwrite current files.

      paths_with_files = MigrationContext.fixture_paths.select do |path|
        Dir[::File.join(path, "{**,*}/*.{yml}")].any?
      end

      if paths_with_files.size > 1 && configuration.overwrite_fixtures?
        raise OverwriteNotAllowedError,
              "can't overwrite fixtures when using multiple folders: #{path_with_files.to_json}. Set overwrite to false"
      end

      # If all folders are still empty, use the first one
      paths_with_files.first || MigrationContext.fixture_paths
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

      def label_for(model_instance:)
        if @rename
          build_label_for(model_instance)
        else
          find_label_for(model_instance) || build_label_for(model_instance)
        end
      end

      private

      def find_label_for(model_instance)
        @pre_existing_fixtures_labels[model_instance_unique_id(model_instance)]
      end

      def build_label_for(model_instance)
        template = @templates[model_instance.class.table_name]

        if template.nil? || template == "DEFAULT"
          default_label(model_instance)
        else
          interpolate_template(template, model_instance)
        end
      end

      def default_label(model_instance)
        model_instance_unique_id(model_instance)
      end

      def model_instance_unique_id(model_instance)
        Migrator.fixture_unique_id(table_name: model_instance.class.table_name, id: model_instance.id)
      end

      def interpolate_template(template, model_instance)
        template.gsub(INTERPOLATION_PATTERN) do
          attribute = ::Regexp.last_match(1).to_sym
          value = if model_instance.respond_to?(attribute)
                    model_instance.send(attribute)
                  else
                    raise WrongFixtureLabelInterpolationError, attribute: attribute, klass: model_instance.class
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

      def serialized_attributes_for(model_instance:)
        column_attributes = model_instance.attributes.select { |a| model_instance.class.column_names.include?(a) }

        # Favour fixtures autofilled timestamps and autogenerated ids
        filtered_attributes = %w[id created_at updated_at]

        serialized_attributes = column_attributes.map do |attribute, value|
          serialize_attribute(model_instance, attribute, value, filtered_attributes)
        end

        serialized_attributes.sort_by(&:first).to_h.except(*filtered_attributes)
      end

      def serialize_attribute(model_instance, attribute, value, filtered_attributes)
        belongs_to_association = model_instance.class.reflect_on_all_associations.filter(&:belongs_to?).find do |a|
          a.foreign_key.to_s == attribute
        end
        type = model_instance.class.type_for_attribute(attribute)

        if belongs_to_association.present?
          filter_belongs_to_columns(belongs_to_association, filtered_attributes)
          serialize_belongs_to(model_instance, belongs_to_association)
        else
          serialize_type(model_instance, attribute, value, type)
        end
      end

      def serialize_belongs_to(model_instance, belongs_to_association)
        associated_model_instance = model_instance.send(belongs_to_association.name)

        reference_label = if belongs_to_association.polymorphic?
                            foreign_type = model_instance.send(belongs_to_association.foreign_type)
                            "#{labeler.label_for(model_instance: associated_model_instance)} (#{foreign_type})"
                          else
                            labeler.label_for(model_instance: associated_model_instance)
                          end

        [belongs_to_association.name.to_s, reference_label]
      end

      # rubocop:disable Metrics/MethodLength
      def serialize_type(model_instance, attribute, value, type)
        if type.respond_to?(:scheme) && encrypted_fixtures?
          [attribute, type.cast_type.serialize(value)]
        elsif type.type == :datetime
          # ActiveRecord::Type::DateTime#serialize returns a TimeWithZone object that makes the YAML dump less clear
          [attribute, model_instance.read_attribute_before_type_cast(attribute)]
          # PostgreSQL jsonb attributes can be saved as hashes or arrays in fixture yaml files
        elsif type.type == :jsonb
          [attribute, value]
        elsif type.respond_to?(:serialize)
          [attribute, type.serialize(value)]
        else
          [attribute, value.to_s]
        end
      end
      # rubocop:enable Metrics/MethodLength

      def filter_belongs_to_columns(belongs_to_association, filtered_attributes)
        filtered_attributes << belongs_to_association.foreign_key.to_s
        return unless belongs_to_association.polymorphic?

        filtered_attributes << belongs_to_association.foreign_type.to_s
      end

      def encrypted_fixtures?
        Rails.configuration.active_record.encryption.encrypt_fixtures
      end
    end
  end
end
