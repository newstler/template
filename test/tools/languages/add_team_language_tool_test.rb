# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Languages
  class AddTeamLanguageToolTest < McpToolTestCase
    setup do
      @team = teams(:two)
      @user = users(:two)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Languages::AddTeamLanguageTool, language_code: "es")
      end
      assert_match(/x-api-key/, error.message)
    end

    test "adds language to team" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Languages::AddTeamLanguageTool, language_code: "es")

      assert result[:success]
      assert_includes @team.active_language_codes, "es"
    end

    test "returns error for non-admin" do
      mock_mcp_request(team: teams(:two), user: users(:one))

      result = call_tool(Languages::AddTeamLanguageTool, language_code: "es")

      assert_not result[:success]
      assert_match(/Admin/, result[:error])
    end

    test "returns error for invalid language code" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Languages::AddTeamLanguageTool, language_code: "xx")

      assert_not result[:success]
      assert_match(/not found/, result[:error])
    end
  end
end
