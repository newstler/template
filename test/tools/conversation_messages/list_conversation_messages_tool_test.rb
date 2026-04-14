# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module ConversationMessages
  class ListConversationMessagesToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @conversation = conversations(:one)
    end

    test "returns messages for a conversation the user participates in" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(
        ConversationMessages::ListConversationMessagesTool,
        conversation_id: @conversation.id
      )

      assert result[:success]
      ids = result[:data].map { |m| m[:id] }
      assert_includes ids, conversation_messages(:first).id
    end

    test "rejects non-participants" do
      mock_mcp_request(team: @team, user: users(:three))

      result = call_tool(
        ConversationMessages::ListConversationMessagesTool,
        conversation_id: @conversation.id
      )

      assert_equal false, result[:success]
    end
  end
end
