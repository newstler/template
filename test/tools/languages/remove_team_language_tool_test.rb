# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Languages
  class RemoveTeamLanguageToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Languages::RemoveTeamLanguageTool, language_code: "es")
      end
      assert_match(/x-api-key/, error.message)
    end

    test "removes language from team" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Languages::RemoveTeamLanguageTool, language_code: "es")

      assert result[:success]
      assert_not_includes @team.active_language_codes, "es"
    end

    test "prevents removing last language" do
      mock_mcp_request(team: @team, user: @user)

      # Remove Spanish first so English is the only one left
      call_tool(Languages::RemoveTeamLanguageTool, language_code: "es")

      result = call_tool(Languages::RemoveTeamLanguageTool, language_code: "en")

      assert_not result[:success]
      assert_match(/At least one language/, result[:error])
    end
  end
end
