# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Notifications
  class MarkNotificationReadToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @notification = Noticed::Notification.find("01961a2a-c0de-7000-8000-b00000000001")
    end

    test "marks a notification as read" do
      mock_mcp_request(team: @team, user: @user)

      assert_nil @notification.read_at

      result = call_tool(Notifications::MarkNotificationReadTool, id: @notification.id)

      assert result[:success]
      assert_not_nil @notification.reload.read_at
    end

    test "returns not_found for unknown id" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Notifications::MarkNotificationReadTool, id: "nonexistent")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end
  end
end
