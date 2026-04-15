# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Users
  class UpdateNotificationPreferencesToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Users::UpdateNotificationPreferencesTool, preferences: {})
      end
      assert_match(/x-api-key/, error.message)
    end

    test "stores sanitized preferences for a known notifier kind" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(
        Users::UpdateNotificationPreferencesTool,
        preferences: { "welcome_notifier" => { "email" => false, "database" => true } }
      )

      assert result[:success]
      @user.reload
      assert_equal({ "email" => false, "database" => true },
                   @user.notification_preferences["welcome_notifier"])
    end

    test "ignores unknown notifier kinds and channels" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(
        Users::UpdateNotificationPreferencesTool,
        preferences: {
          "bogus_notifier" => { "email" => true },
          "welcome_notifier" => { "sms" => true, "email" => false }
        }
      )

      assert result[:success]
      @user.reload
      assert_nil @user.notification_preferences["bogus_notifier"]
      assert_equal({ "email" => false }, @user.notification_preferences["welcome_notifier"])
    end
  end
end
