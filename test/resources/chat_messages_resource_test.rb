# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

class ChatMessagesResourceTest < McpResourceTestCase
  setup do
    @chat = chats(:one)
  end

  test "returns message directing to tool" do
    result = parse_resource(call_resource(Mcp::ChatMessagesResource, chat_id: @chat.id))

    assert_equal "Use the 'list_messages' tool for authenticated message access", result[:message]
    assert_equal "list_messages", result[:tool]
    assert_equal @chat.id, result[:arguments][:chat_id]
  end
end
