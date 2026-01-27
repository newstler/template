# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Models
  class ListModelsToolTest < McpToolTestCase
    test "returns models without authentication" do
      result = call_tool(Models::ListModelsTool)

      assert result[:success]
      assert_kind_of Array, result[:data]
    end

    test "filters by provider" do
      result = call_tool(Models::ListModelsTool, provider: "openai", enabled_only: false)

      assert result[:success]
      result[:data].each do |model|
        assert_equal "openai", model[:provider]
      end
    end

    test "returns all models when enabled_only is false" do
      result = call_tool(Models::ListModelsTool, enabled_only: false)

      assert result[:success]
      assert result[:data].size >= 2 # At least our fixtures
    end
  end
end
