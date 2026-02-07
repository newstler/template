# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Chats
  class UpdateChatToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @chat = chats(:one)
      @new_model = models(:claude)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Chats::UpdateChatTool, id: @chat.id, model_id: @new_model.id)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "updates chat model when model is enabled" do
      mock_mcp_request(team: @team, user: @user)

      # Skip if no providers are configured (no API keys in test)
      skip "No providers configured" if Model.configured_providers.empty?

      result = call_tool(Chats::UpdateChatTool, id: @chat.id, model_id: @new_model.id)

      assert result[:success]
      assert_equal @new_model.model_id, result[:data][:model_id]
      @chat.reload
      assert_equal @new_model.model_id, @chat.model_id
    end

    test "returns error when new model is not enabled" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::UpdateChatTool, id: @chat.id, model_id: @new_model.id)

      # Either success (if API key configured) or error (if not)
      if Model.enabled.find_by(id: @new_model.id)
        assert result[:success]
      else
        assert_not result[:success]
        assert_equal "invalid_model", result[:code]
      end
    end

    test "returns error for non-existent chat" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::UpdateChatTool, id: "nonexistent", model_id: @new_model.id)

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "returns error for invalid model" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::UpdateChatTool, id: @chat.id, model_id: "nonexistent")

      assert_not result[:success]
      assert_equal "invalid_model", result[:code]
    end
  end
end
