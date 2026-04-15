# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Dashboards
  class ShowAdminDashboardToolTest < McpToolTestCase
    test "requires admin authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Dashboards::ShowAdminDashboardTool)
      end
      assert_match(/[Aa]dmin authentication/, error.message)
    end

    test "is flagged as admin-only" do
      assert Dashboards::ShowAdminDashboardTool.admin_only?
    end
  end
end
