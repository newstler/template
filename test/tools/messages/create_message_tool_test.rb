# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Messages
  class CreateMessageToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @chat = chats(:one)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Messages::CreateMessageTool, chat_id: @chat.id, content: "Hello")
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns error for non-existent chat" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Messages::CreateMessageTool, chat_id: "nonexistent", content: "Hello")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "cannot send message to other user's chat" do
      mock_mcp_request(team: @team, user: @user)
      other_chat = chats(:two)

      result = call_tool(Messages::CreateMessageTool, chat_id: other_chat.id, content: "Hello")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    # Note: Full message creation test requires mocking the LLM API
    # which is outside the scope of unit tests
  end
end
