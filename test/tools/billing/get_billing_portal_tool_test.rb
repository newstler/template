# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Billing
  class GetBillingPortalToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @admin = users(:one)
    end

    test "returns error when no stripe customer" do
      mock_mcp_request(team: @team, user: @admin)

      result = call_tool(Billing::GetBillingPortalTool, return_url: "http://example.com/billing")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "rejects non-admin member" do
      team_two = teams(:two)
      mock_mcp_request(team: team_two, user: @admin)

      result = call_tool(Billing::GetBillingPortalTool, return_url: "http://example.com/billing")

      assert_not result[:success]
      assert_equal "forbidden", result[:code]
    end

    test "requires authentication" do
      assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Billing::GetBillingPortalTool, return_url: "http://example.com/billing")
      end
    end
  end
end
