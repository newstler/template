# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Models
  class RefreshModelsToolTest < McpToolTestCase
    setup do
      @admin = admins(:one)
    end

    test "requires admin authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Models::RefreshModelsTool)
      end
      assert_match(/Admin authentication required/, error.message)
    end

    test "requires admin even with team and user authentication" do
      mock_mcp_request(team: teams(:one), user: users(:one))

      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Models::RefreshModelsTool)
      end
      assert_match(/Admin authentication required/, error.message)
    end

    # Note: Full refresh test requires mocking the provider APIs
    # which is outside the scope of unit tests
  end
end
