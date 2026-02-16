# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Articles
  class DeleteArticleToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @article = articles(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Articles::DeleteArticleTool, id: @article.id)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "deletes article" do
      mock_mcp_request(team: @team, user: @user)

      assert_difference "Article.count", -1 do
        result = call_tool(Articles::DeleteArticleTool, id: @article.id)
        assert result[:success]
      end
    end

    test "returns error for non-existent article" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Articles::DeleteArticleTool, id: "nonexistent")
      assert_not result[:success]
    end
  end
end
