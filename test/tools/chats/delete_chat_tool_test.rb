# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Chats
  class DeleteChatToolTest < McpToolTestCase
    setup do
      @user = users(:one)
      @chat = chats(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Chats::DeleteChatTool, id: @chat.id)
      end
      assert_match(/Authentication required/, error.message)
    end

    test "deletes chat" do
      mock_mcp_request(user: @user)

      assert_difference "@user.chats.count", -1 do
        result = call_tool(Chats::DeleteChatTool, id: @chat.id)

        assert result[:success]
        assert_equal @chat.id, result[:data][:id]
      end
    end

    test "returns error for non-existent chat" do
      mock_mcp_request(user: @user)

      result = call_tool(Chats::DeleteChatTool, id: "nonexistent")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "cannot delete other user's chat" do
      mock_mcp_request(user: @user)
      other_chat = chats(:two)

      result = call_tool(Chats::DeleteChatTool, id: other_chat.id)

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end
  end
end
