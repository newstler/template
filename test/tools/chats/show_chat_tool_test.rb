# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Chats
  class ShowChatToolTest < McpToolTestCase
    setup do
      @user = users(:one)
      @chat = chats(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Chats::ShowChatTool, id: @chat.id)
      end
      assert_match(/Authentication required/, error.message)
    end

    test "returns chat with messages when authenticated" do
      mock_mcp_request(user: @user)

      result = call_tool(Chats::ShowChatTool, id: @chat.id)

      assert result[:success]
      assert_equal @chat.id, result[:data][:id]
      assert_kind_of Array, result[:data][:messages]
    end

    test "returns chat without messages when include_messages is false" do
      mock_mcp_request(user: @user)

      result = call_tool(Chats::ShowChatTool, id: @chat.id, include_messages: false)

      assert result[:success]
      assert_equal @chat.id, result[:data][:id]
      assert_nil result[:data][:messages]
    end

    test "returns error for non-existent chat" do
      mock_mcp_request(user: @user)

      result = call_tool(Chats::ShowChatTool, id: "nonexistent")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "returns error for other user's chat" do
      mock_mcp_request(user: @user)
      other_chat = chats(:two)

      result = call_tool(Chats::ShowChatTool, id: other_chat.id)

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end
  end
end
