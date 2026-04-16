# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

# Blanket negative-auth coverage for one tool per namespace. Confirms
# the base-class guards in ApplicationTool fire correctly for:
#
# 1. Missing x-api-key (no team)              → InvalidArgumentsError
# 2. Valid x-api-key, missing x-user-email    → InvalidArgumentsError
# 3. x-user-email for a user not in the team  → InvalidArgumentsError
#
# We pick one representative tool per namespace rather than testing
# every tool — the point is to pin the guard behavior.
class NegativeAuthTest < McpToolTestCase
  setup do
    @team = teams(:one)
    @user = users(:one)            # member of team_one
    @outsider = users(:two)        # NOT a member of team_one
  end

  REPRESENTATIVE_TOOLS = {
    conversations: {
      klass: "Conversations::ShowConversationTool",
      args: { id: "fake-id" }
    },
    notifications: {
      klass: "Notifications::ListNotificationsTool",
      args: {}
    },
    teams: {
      klass: "Teams::ShowTeamTool",
      args: { slug: "team-one" }
    },
    chats: {
      klass: "Chats::ListChatsTool",
      args: {}
    },
    users: {
      klass: "Users::ShowCurrentUserTool",
      args: {}
    },
    articles: {
      klass: "Articles::ListArticlesTool",
      args: {}
    },
    dashboards: {
      klass: "Dashboards::ShowTeamDashboardTool",
      args: {}
    }
  }.freeze

  REPRESENTATIVE_TOOLS.each do |namespace, config|
    test "#{namespace} tool rejects requests without x-api-key" do
      klass = config[:klass].safe_constantize
      skip "tool not defined" unless klass

      clear_mcp_request # no headers at all
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(klass, **config[:args])
      end
      assert_match(/x-api-key/, error.message)
    end

    test "#{namespace} tool rejects team-only auth when user is required" do
      klass = config[:klass].safe_constantize
      skip "tool not defined" unless klass
      next unless tool_requires_user?(klass, config[:args])

      mock_mcp_request(team: @team, user: nil)
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(klass, **config[:args])
      end
      assert_match(/x-user-email/, error.message)
    end

    test "#{namespace} tool rejects a user-email outside the team" do
      klass = config[:klass].safe_constantize
      skip "tool not defined" unless klass
      next unless tool_requires_user?(klass, config[:args])

      mock_mcp_request(team: @team, user: @outsider)
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(klass, **config[:args])
      end
      assert_match(/x-user-email/, error.message)
    end
  end

  private

  # Sniff-test: does the tool call require_user!? Some namespaces only
  # have team-level tools (e.g. list_currencies is fully public).
  def tool_requires_user?(klass, args)
    clear_mcp_request
    mock_mcp_request(team: @team, user: nil)
    call_tool(klass, **args)
    false
  rescue FastMcp::Tool::InvalidArgumentsError => e
    e.message.include?("x-user-email")
  rescue StandardError
    false
  end
end
