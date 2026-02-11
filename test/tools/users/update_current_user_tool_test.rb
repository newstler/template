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

    test "updates user locale" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Users::UpdateCurrentUserTool, locale: "es")

      assert result[:success]
      assert_equal "es", result[:data][:locale]
      @user.reload
      assert_equal "es", @user.locale
    end

    test "clears locale with auto" do
      @user.update!(locale: "es")
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Users::UpdateCurrentUserTool, locale: "auto")

      assert result[:success]
      @user.reload
      assert_nil @user.locale
    end

    test "returns error when no updates provided" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Users::UpdateCurrentUserTool)

      assert_not result[:success]
      assert_equal "no_updates", result[:code]
    end
  end
end
