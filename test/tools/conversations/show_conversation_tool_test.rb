# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Conversations
  class ShowConversationToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @conversation = conversations(:one)
    end

    test "returns conversation with messages" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Conversations::ShowConversationTool, id: @conversation.id)

      assert result[:success]
      assert_equal @conversation.id, result[:data][:id]
      assert_kind_of Array, result[:data][:messages]
    end

    test "404 for unknown conversation" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Conversations::ShowConversationTool, id: "00000000-0000-0000-0000-000000000000")
      assert_equal false, result[:success]
    end

    test "rejects non-participant team members" do
      mock_mcp_request(team: @team, user: users(:three))

      result = call_tool(Conversations::ShowConversationTool, id: @conversation.id)
      assert_equal false, result[:success]
    end
  end
end
