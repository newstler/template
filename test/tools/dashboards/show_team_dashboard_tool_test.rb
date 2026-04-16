# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Dashboards
  class ShowTeamDashboardToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Dashboards::ShowTeamDashboardTool)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "requires user email when team authenticated" do
      mock_mcp_request(team: @team)
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Dashboards::ShowTeamDashboardTool)
      end
      assert_match(/x-user-email/, error.message)
    end

    test "returns core dashboard aggregates as JSON" do
      mock_mcp_request(team: @team, user: @user)
      result = call_tool(Dashboards::ShowTeamDashboardTool)

      assert result[:success]
      data = result[:data]
      assert_equal @team.id, data[:team][:id]
      assert_equal @team.slug, data[:team][:slug]
      assert_equal "30d", data[:range][:key]
      assert data[:totals].key?(:members)
      assert data[:totals].key?(:chats)
      assert data[:totals].key?(:articles)
      assert data[:recent].key?(:chats)
      assert_kind_of Hash, data[:chats_timeline]
    end

    test "accepts 7d range" do
      mock_mcp_request(team: @team, user: @user)
      result = call_tool(Dashboards::ShowTeamDashboardTool, range: "7d")

      assert result[:success]
      assert_equal "7d", result[:data][:range][:key]
    end

    test "unknown range falls back to 30d" do
      mock_mcp_request(team: @team, user: @user)
      result = call_tool(Dashboards::ShowTeamDashboardTool, range: "bogus")

      assert result[:success]
      assert_equal "30d", result[:data][:range][:key]
    end
  end
end
