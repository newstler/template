# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Articles
  class UpdateArticleToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @article = articles(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Articles::UpdateArticleTool, id: @article.id, title: "Updated")
      end
      assert_match(/x-api-key/, error.message)
    end

    test "updates article" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Articles::UpdateArticleTool, id: @article.id, title: "Updated Title")

      assert result[:success]
      assert_equal "Updated Title", @article.reload.title
    end
  end
end
