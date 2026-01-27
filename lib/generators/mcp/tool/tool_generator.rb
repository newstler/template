# frozen_string_literal: true

module Mcp
  module Generators
    class ToolGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :actions, type: :array, default: [ "call" ], banner: "action action"

      class_option :admin, type: :boolean, default: false, desc: "Require admin authentication"

      def create_tool_file
        template "tool.rb.tt", File.join("app/tools", class_path, "#{file_name}_tool.rb")
      end

      def create_test_file
        template "tool_test.rb.tt", File.join("test/tools", class_path, "#{file_name}_tool_test.rb")
      end

      private

      def tool_class_name
        "#{class_name.gsub('::', '')}Tool"
      end

      def full_tool_class_name
        if class_path.any?
          "#{class_path.map(&:camelize).join('::')}::#{tool_class_name}"
        else
          tool_class_name
        end
      end

      def namespace_module
        class_path.map(&:camelize).join("::")
      end

      def admin_only?
        options[:admin]
      end

      def humanized_name
        file_name.humanize
      end
    end
  end
end
