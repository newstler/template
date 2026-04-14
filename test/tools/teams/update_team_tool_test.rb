# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Teams
  class UpdateTeamToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @owner = users(:one)           # owner of team one
      @member = users(:user_four)    # plain member of team one (if present)
    rescue StandardError
      @member = nil
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Teams::UpdateTeamTool, name: "New Name")
      end
      assert_match(/x-api-key/, error.message)
    end

    test "owner can update default_currency" do
      mock_mcp_request(team: @team, user: @owner)
      result = call_tool(Teams::UpdateTeamTool, default_currency: "EUR")

      assert result[:success]
      assert_equal "EUR", result[:data][:default_currency]
      @team.reload
      assert_equal "EUR", @team.default_currency
    end

    test "owner can update country_code" do
      mock_mcp_request(team: @team, user: @owner)
      result = call_tool(Teams::UpdateTeamTool, country_code: "DE")

      assert result[:success]
      assert_equal "DE", result[:data][:country_code]
      @team.reload
      assert_equal "DE", @team.country_code
    end

    test "returns error when no updates provided" do
      mock_mcp_request(team: @team, user: @owner)
      result = call_tool(Teams::UpdateTeamTool)

      assert_not result[:success]
      assert_equal "no_updates", result[:code]
    end
  end
end
