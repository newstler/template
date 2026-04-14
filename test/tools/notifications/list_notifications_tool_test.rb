# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Notifications
  class ListNotificationsToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires user authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Notifications::ListNotificationsTool)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns user notifications when authenticated" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Notifications::ListNotificationsTool)

      assert result[:success]
      assert_kind_of Array, result[:data]
    end

    test "respects limit parameter" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Notifications::ListNotificationsTool, limit: 1)

      assert result[:success]
      assert result[:data].size <= 1
    end

    test "filters by unread_only" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Notifications::ListNotificationsTool, unread_only: true)

      assert result[:success]
      result[:data].each do |n|
        assert_nil n[:read_at]
      end
    end
  end
end
