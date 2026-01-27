# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Chats
  class ListChatsToolTest < McpToolTestCase
    setup do
      @user = users(:one)
      @chat = chats(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Chats::ListChatsTool)
      end
      assert_match(/Authentication required/, error.message)
    end

    test "returns user chats when authenticated" do
      mock_mcp_request(user: @user)

      result = call_tool(Chats::ListChatsTool)

      assert result[:success]
      assert_kind_of Array, result[:data]
      assert_includes result[:data].map { |c| c[:id] }, @chat.id
    end

    test "respects limit parameter" do
      mock_mcp_request(user: @user)

      result = call_tool(Chats::ListChatsTool, limit: 1)

      assert result[:success]
      assert_equal 1, result[:data].size
    end

    test "returns chats in recent order by default" do
      mock_mcp_request(user: @user)

      result = call_tool(Chats::ListChatsTool)

      assert result[:success]
      # Most recent first
      timestamps = result[:data].map { |c| c[:created_at] }
      assert_equal timestamps, timestamps.sort.reverse
    end
  end
end
