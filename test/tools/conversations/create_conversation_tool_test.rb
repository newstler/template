# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Conversations
  class CreateConversationToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
    end

    test "creates a conversation with the current user as participant" do
      mock_mcp_request(team: @team, user: @user)

      assert_difference -> { @team.conversations.count }, 1 do
        result = call_tool(Conversations::CreateConversationTool, title: "New thread")
        assert result[:success]
        assert_includes result[:data][:participant_ids], @user.id
      end
    end

    test "adds additional participants by email if they are team members" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(
        Conversations::CreateConversationTool,
        title: "With friends",
        participant_emails: [ users(:three).email ]
      )
      assert result[:success]
      assert_includes result[:data][:participant_ids], users(:three).id
    end

    test "silently skips non-member emails" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(
        Conversations::CreateConversationTool,
        title: "Private",
        participant_emails: [ users(:two).email ] # users(:two) is in team_two, not team_one
      )
      assert result[:success]
      assert_not_includes result[:data][:participant_ids], users(:two).id
    end
  end
end
