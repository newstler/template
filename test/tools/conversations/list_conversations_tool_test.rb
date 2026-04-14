# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Conversations
  class ListConversationsToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "requires authentication" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Conversations::ListConversationsTool)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "returns conversations where user is a participant" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Conversations::ListConversationsTool)

      assert result[:success]
      ids = result[:data].map { |c| c[:id] }
      assert_includes ids, conversations(:one).id
    end
  end
end
