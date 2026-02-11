# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Articles
  class ShowArticleToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @article = articles(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Articles::ShowArticleTool, id: @article.id)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns article details" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Articles::ShowArticleTool, id: @article.id)

      assert result[:success]
      assert_equal @article.id, result[:data][:id]
      assert_equal "First Article", result[:data][:title]
    end

    test "returns error for non-existent article" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Articles::ShowArticleTool, id: "nonexistent")

      assert_not result[:success]
    end
  end
end
