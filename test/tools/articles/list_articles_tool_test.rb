# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Articles
  class ListArticlesToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Articles::ListArticlesTool)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns team articles" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Articles::ListArticlesTool)

      assert result[:success]
      assert_kind_of Array, result[:data]
      ids = result[:data].map { |a| a[:id] }
      assert_includes ids, articles(:one).id
    end
  end
end
