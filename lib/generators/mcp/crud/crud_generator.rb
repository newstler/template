# frozen_string_literal: true

module Mcp
  module Generators
    class CrudGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      class_option :skip_resource, type: :boolean, default: false, desc: "Skip resource generation"

      ACTIONS = %w[list show create update delete].freeze

      def create_tool_files
        ACTIONS.each do |action|
          @action = action
          template "#{action}_tool.rb.tt", File.join("app/tools", plural_name, "#{action}_#{singular_name}_tool.rb")
          template "#{action}_tool_test.rb.tt", File.join("test/tools", plural_name, "#{action}_#{singular_name}_tool_test.rb")
        end
      end

      def create_resource_file
        return if options[:skip_resource]

        template "resource.rb.tt", File.join("app/resources/mcp", "#{plural_name}_resource.rb")
        template "resource_test.rb.tt", File.join("test/resources", "#{plural_name}_resource_test.rb")
      end

      private

      def model_class
        class_name.singularize
      end

      def plural_class_name
        class_name.pluralize.camelize
      end

      def humanized_name
        singular_name.humanize
      end

      def humanized_plural
        plural_name.humanize
      end
    end
  end
end
