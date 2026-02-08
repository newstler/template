# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Users
  class ShowCurrentUserToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Users::ShowCurrentUserTool)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns current user info" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Users::ShowCurrentUserTool)

      assert result[:success]
      assert_equal @user.id, result[:data][:id]
      assert_equal @user.email, result[:data][:email]
      assert_equal @user.name, result[:data][:name]
    end
  end
end
