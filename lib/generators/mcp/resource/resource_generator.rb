# frozen_string_literal: true

module Mcp
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      class_option :uri, type: :string, desc: "Custom URI for the resource"

      def create_resource_file
        template "resource.rb.tt", File.join("app/resources/mcp", "#{file_name}_resource.rb")
      end

      def create_test_file
        template "resource_test.rb.tt", File.join("test/resources", "#{file_name}_resource_test.rb")
      end

      private

      def resource_class_name
        "#{class_name.gsub('::', '')}Resource"
      end

      def resource_uri
        options[:uri] || "app:///#{file_name.pluralize}"
      end

      def humanized_name
        file_name.humanize
      end
    end
  end
end
