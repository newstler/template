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

    test "updates preferred_currency" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Users::UpdateCurrentUserTool, preferred_currency: "EUR")

      assert result[:success]
      assert_equal "EUR", result[:data][:preferred_currency]
      @user.reload
      assert_equal "EUR", @user.preferred_currency
    end

    test "clears preferred_currency with auto" do
      @user.update!(preferred_currency: "EUR")
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Users::UpdateCurrentUserTool, preferred_currency: "auto")

      assert result[:success]
      @user.reload
      assert_nil @user.preferred_currency
    end

    test "updates residence_country_code" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Users::UpdateCurrentUserTool, residence_country_code: "DE")

      assert result[:success]
      assert_equal "DE", result[:data][:residence_country_code]
      @user.reload
      assert_equal "DE", @user.residence_country_code
    end
  end
end
