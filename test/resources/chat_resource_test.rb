# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

class McpChatResourceTest < McpResourceTestCase
  setup do
    @chat = chats(:one)
  end

  test "returns message directing to tool" do
    result = parse_resource(call_resource(Mcp::ChatResource, id: @chat.id))

    assert_equal "Use the 'show_chat' tool for authenticated chat access", result[:message]
    assert_equal "show_chat", result[:tool]
    assert_equal @chat.id, result[:arguments][:id]
  end
end
