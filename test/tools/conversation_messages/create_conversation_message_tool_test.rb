# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module ConversationMessages
  class CreateConversationMessageToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @conversation = conversations(:one)
    end

    test "creates a message authored by the current user" do
      mock_mcp_request(team: @team, user: @user)

      assert_difference -> { @conversation.conversation_messages.count }, 1 do
        result = call_tool(
          ConversationMessages::CreateConversationMessageTool,
          conversation_id: @conversation.id,
          content: "Hello via MCP"
        )
        assert result[:success]
        assert_equal "Hello via MCP", result[:data][:content]
      end
    end

    test "rejects non-participants" do
      mock_mcp_request(team: @team, user: users(:three))

      result = call_tool(
        ConversationMessages::CreateConversationMessageTool,
        conversation_id: @conversation.id,
        content: "Sneaky"
      )

      assert_equal false, result[:success]
    end

    test "404 for unknown conversation" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(
        ConversationMessages::CreateConversationMessageTool,
        conversation_id: "00000000-0000-0000-0000-000000000000",
        content: "Hi"
      )
      assert_equal false, result[:success]
    end
  end
end
