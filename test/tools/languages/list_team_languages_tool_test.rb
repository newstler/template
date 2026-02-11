# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Languages
  class ListTeamLanguagesToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Languages::ListTeamLanguagesTool)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns team active languages" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Languages::ListTeamLanguagesTool)

      assert result[:success]
      codes = result[:data].map { |l| l[:code] }
      assert_includes codes, "en"
      assert_includes codes, "es"
    end
  end
end
