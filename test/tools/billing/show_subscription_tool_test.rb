# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Billing
  class ShowSubscriptionToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @admin = users(:one) # owner of team_one
      @member = users(:one) # member of team_two (not admin)
    end

    test "returns subscription info for admin" do
      @team.update!(subscription_status: "active", current_period_ends_at: Time.utc(2026, 3, 1))
      mock_mcp_request(team: @team, user: @admin)

      result = call_tool(Billing::ShowSubscriptionTool)

      assert result[:success]
      assert_equal "active", result[:data][:subscription_status]
      assert result[:data][:subscribed]
    end

    test "rejects non-admin member" do
      team_two = teams(:two)
      mock_mcp_request(team: team_two, user: @member)

      # user_one is member (not admin) of team_two
      result = call_tool(Billing::ShowSubscriptionTool)

      assert_not result[:success]
      assert_equal "forbidden", result[:code]
    end

    test "requires authentication" do
      assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Billing::ShowSubscriptionTool)
      end
    end
  end
end
