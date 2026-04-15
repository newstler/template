require "rails/generators/active_record"

module Embeddable
  module Generators
    # Install generator for the Embeddable concern.
    #
    # Usage:
    #   bin/rails generate embeddable:install Candidate 1536 --metadata nationality profession
    #
    # Creates a migration that builds a vec0 virtual table named
    # +<model_table>_embeddings+ with a string primary key, a
    # +float[N]+ embedding column, a +source_hash+ column used to
    # skip unchanged re-embeddings, and the requested metadata columns
    # for WHERE-aware KNN pre-filtering.
    class InstallGenerator < ::Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      argument :dimension, type: :numeric, default: 1536, banner: "dimension"
      class_option :metadata, type: :array, default: [],
        desc: "Metadata columns for pre-filtering (space-separated names)"

      def create_migration_file
        migration_template "migration.rb.tt", "db/migrate/create_#{embeddings_table_name}.rb"
      end

      def migration_class_name
        "Create#{embeddings_table_name.camelize}"
      end

      def target_table_name
        name.tableize
      end

      def embeddings_table_name
        "#{target_table_name}_embeddings"
      end

      def distance_metric
        "cosine"
      end

      def metadata_columns
        options[:metadata]
      end
    end
  end
end
