# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Models
  class ShowModelToolTest < McpToolTestCase
    setup do
      @model = models(:gpt4)
    end

    test "returns model by ID" do
      result = call_tool(Models::ShowModelTool, model_id: @model.id)

      assert result[:success]
      assert_equal @model.id, result[:data][:id]
      assert_equal @model.name, result[:data][:name]
    end

    test "returns model by model_id string" do
      result = call_tool(Models::ShowModelTool, model_id: "gpt-4")

      assert result[:success]
      assert_equal @model.id, result[:data][:id]
    end

    test "returns error for non-existent model" do
      result = call_tool(Models::ShowModelTool, model_id: "nonexistent")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end
  end
end
