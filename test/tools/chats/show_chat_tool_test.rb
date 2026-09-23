# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Chats
  class ShowChatToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @chat = chats(:one)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Chats::ShowChatTool, id: @chat.id)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns chat with messages when authenticated" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::ShowChatTool, id: @chat.id)

      assert result[:success]
      assert_equal @chat.id, result[:data][:id]
      assert_kind_of Array, result[:data][:messages]
    end

    test "returns chat without messages when include_messages is false" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::ShowChatTool, id: @chat.id, include_messages: false)

      assert result[:success]
      assert_equal @chat.id, result[:data][:id]
      assert_nil result[:data][:messages]
    end

    test "returns error for non-existent chat" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::ShowChatTool, id: "nonexistent")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "returns error for other user's chat" do
      mock_mcp_request(team: @team, user: @user)
      other_chat = chats(:two)

      result = call_tool(Chats::ShowChatTool, id: other_chat.id)

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "serializes tokens and cost from usages" do
      mock_mcp_request(team: @team, user: @user)

      message = call_tool(Chats::ShowChatTool, id: @chat.id)[:data][:messages].find { |m| m[:role] == "assistant" }

      assert_equal "gpt-4", message[:model_id]
      assert_equal 10, message[:input_tokens]
      assert_equal 15, message[:output_tokens]
      assert_in_delta 0.0012, message[:cost]
    end

    test "an unpriced attempt does not blank the chat total" do
      mock_mcp_request(team: @team, user: @user)
      @chat.ruby_llm_usages.create!(operation: "chat", provider: "openai", model: "gpt-4", status: "failed")

      assert_in_delta 0.0012, call_tool(Chats::ShowChatTool, id: @chat.id)[:data][:total_cost]
    end
  end
end
