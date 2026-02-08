# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Billing
  class ResumeSubscriptionToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @admin = users(:one)
    end

    test "returns error when no pending cancellation" do
      @team.update!(subscription_status: "active", cancel_at_period_end: false)
      mock_mcp_request(team: @team, user: @admin)

      result = call_tool(Billing::ResumeSubscriptionTool)

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end

    test "rejects non-admin member" do
      team_two = teams(:two)
      mock_mcp_request(team: team_two, user: @admin)

      result = call_tool(Billing::ResumeSubscriptionTool)

      assert_not result[:success]
      assert_equal "forbidden", result[:code]
    end

    test "requires authentication" do
      assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Billing::ResumeSubscriptionTool)
      end
    end
  end
end
