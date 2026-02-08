# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Users
  class UpdateCurrentUserToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Users::UpdateCurrentUserTool, name: "New Name")
      end
      assert_match(/x-api-key/, error.message)
    end

    test "updates user name" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Users::UpdateCurrentUserTool, name: "Updated Name")

      assert result[:success]
      assert_equal "Updated Name", result[:data][:name]
      @user.reload
      assert_equal "Updated Name", @user.name
    end

    test "returns error when no updates provided" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Users::UpdateCurrentUserTool)

      assert_not result[:success]
      assert_equal "no_updates", result[:code]
    end
  end
end
