# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Articles
  class CreateArticleToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Articles::CreateArticleTool, title: "Test")
      end
      assert_match(/x-api-key/, error.message)
    end

    test "creates article" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Articles::CreateArticleTool, title: "MCP Article", body: "Created via MCP")

      assert result[:success]
      assert_equal "MCP Article", result[:data][:title]
      assert Article.find(result[:data][:id])
    end
  end
end
