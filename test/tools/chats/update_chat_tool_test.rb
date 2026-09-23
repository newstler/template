# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Chats
  class UpdateChatToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @chat = chats(:one)
      @new_model = ruby_llm_models(:claude)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Chats::UpdateChatTool, id: @chat.id, model_id: @new_model.model_id)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "switches the chat to another enabled model" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::UpdateChatTool, id: @chat.id, model_id: @new_model.model_id)

      assert result[:success], result.inspect
      assert_equal @new_model.model_id, result[:data][:model_id]
      assert_equal @new_model, @chat.reload.model
    end

    test "returns not_found for non-existent chat" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::UpdateChatTool, id: "nonexistent", model_id: @new_model.model_id)

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "returns invalid_model when model is not enabled" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::UpdateChatTool, id: @chat.id, model_id: "nonexistent")

      assert_not result[:success]
      assert_equal "invalid_model", result[:code]
    end
  end
end
