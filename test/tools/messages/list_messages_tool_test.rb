# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Messages
  class ListMessagesToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @chat = chats(:one)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Messages::ListMessagesTool, chat_id: @chat.id)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns messages for chat" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Messages::ListMessagesTool, chat_id: @chat.id)

      assert result[:success]
      assert_kind_of Array, result[:data]
    end

    test "respects limit parameter" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Messages::ListMessagesTool, chat_id: @chat.id, limit: 1)

      assert result[:success]
      assert result[:data].size <= 1
    end

    test "returns error for non-existent chat" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Messages::ListMessagesTool, chat_id: "nonexistent")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "cannot access other user's chat messages" do
      mock_mcp_request(team: @team, user: @user)
      other_chat = chats(:two)

      result = call_tool(Messages::ListMessagesTool, chat_id: other_chat.id)

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end
  end
end
