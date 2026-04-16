require "rails/generators/active_record"

module Searchable
  module Generators
    # Install generator for the Searchable concern.
    #
    # Usage:
    #   bin/rails generate searchable:install Candidate profession skills notes
    #
    # Creates a migration that builds an FTS5 virtual table named
    # `<model_table>_fts` with an UNINDEXED `id` column + the requested fields,
    # using the tokenizer from Setting.search_tokenizer.
    class InstallGenerator < ::Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      argument :fields, type: :array, default: [], banner: "field1 field2 field3"

      def create_migration_file
        migration_template "migration.rb.tt", "db/migrate/create_#{fts_table_name}.rb"
      end

      def migration_class_name
        "Create#{fts_table_name.camelize}"
      end

      def target_table_name
        name.tableize
      end

      def fts_table_name
        "#{target_table_name}_fts"
      end

      def field_list
        fields.join(", ")
      end

      def tokenizer
        Setting.search_tokenizer
      rescue StandardError
        "porter unicode61 remove_diacritics 2"
      end
    end
  end
end
