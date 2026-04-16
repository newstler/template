# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Notifications
  class MarkAllNotificationsReadToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "marks all unread notifications as read" do
      mock_mcp_request(team: @team, user: @user)

      unread_before = @user.notifications.unread.count
      result = call_tool(Notifications::MarkAllNotificationsReadTool)

      assert result[:success]
      assert_equal unread_before, result[:data][:marked_read_count]
      assert_equal 0, @user.notifications.unread.count
    end
  end
end
