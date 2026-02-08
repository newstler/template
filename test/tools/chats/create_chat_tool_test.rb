# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Chats
  class CreateChatToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @model = models(:gpt4)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Chats::CreateChatTool, model_id: @model.id)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "creates chat with valid model when model is enabled" do
      mock_mcp_request(team: @team, user: @user)

      # Skip if no providers are configured (no API keys in test)
      skip "No providers configured" if Model.configured_providers.empty?

      assert_difference "@user.chats.count", 1 do
        result = call_tool(Chats::CreateChatTool, model_id: @model.id)

        assert result[:success]
        assert result[:data][:id].present?
        assert_equal @model.model_id, result[:data][:model_id]
      end
    end

    test "returns error when model is not enabled" do
      mock_mcp_request(team: @team, user: @user)

      # In test environment without API keys, models are not enabled
      result = call_tool(Chats::CreateChatTool, model_id: @model.id)

      # Either success (if API key configured) or error (if not)
      if Model.enabled.find_by(id: @model.id)
        assert result[:success]
      else
        assert_not result[:success]
        assert_equal "invalid_model", result[:code]
      end
    end

    test "returns error for invalid model" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::CreateChatTool, model_id: "nonexistent")

      assert_not result[:success]
      assert_equal "invalid_model", result[:code]
    end
  end
end
