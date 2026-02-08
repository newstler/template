# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

class UserChatsResourceTest < McpResourceTestCase
  test "returns message directing to tool" do
    result = parse_resource(call_resource(Mcp::UserChatsResource))

    assert_equal "Use the 'list_chats' tool for authenticated chat list", result[:message]
    assert_equal "list_chats", result[:tool]
  end
end
