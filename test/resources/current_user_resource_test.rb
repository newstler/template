# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

class CurrentUserResourceTest < McpResourceTestCase
  test "returns message directing to tool" do
    result = parse_resource(call_resource(Mcp::CurrentUserResource))

    assert_equal "Use the 'show_current_user' tool for authenticated user info", result[:message]
    assert_equal "show_current_user", result[:tool]
  end
end
