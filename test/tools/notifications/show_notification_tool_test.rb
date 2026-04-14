# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Notifications
  class ShowNotificationToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @notification = Noticed::Notification.find("01961a2a-c0de-7000-8000-b00000000001")
    end

    test "requires user authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Notifications::ShowNotificationTool, id: @notification.id)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns notification details when owned by user" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Notifications::ShowNotificationTool, id: @notification.id)

      assert result[:success]
      assert_equal @notification.id, result[:data][:id]
      assert_equal "WelcomeNotifier", result[:data][:type]
    end

    test "returns not_found for unknown id" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Notifications::ShowNotificationTool, id: "nonexistent")

      assert_not result[:success]
      assert_equal "not_found", result[:code]
    end
  end
end
