# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Users
  class ShowCurrentUserToolTest < McpToolTestCase
    setup do
      @user = users(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Users::ShowCurrentUserTool)
      end
      assert_match(/Authentication required/, error.message)
    end

    test "returns current user info" do
      mock_mcp_request(user: @user)

      result = call_tool(Users::ShowCurrentUserTool)

      assert result[:success]
      assert_equal @user.id, result[:data][:id]
      assert_equal @user.email, result[:data][:email]
      assert_equal @user.name, result[:data][:name]
    end
  end
end
