# frozen_string_literal: true

# Helper module for testing MCP tools and resources
module McpTestHelper
  # Store current test team/user/admin for authentication
  attr_accessor :mcp_test_team, :mcp_test_user, :mcp_test_admin

  # Set up request context for MCP tools/resources
  # @param team [Team, nil] Team to authenticate with (via API key)
  # @param user [User, nil] User to authenticate with (via email header)
  # @param admin [Admin, nil] Admin to authenticate with
  def mock_mcp_request(team: nil, user: nil, admin: nil)
    @mcp_test_team = team
    @mcp_test_user = user
    @mcp_test_admin = admin
  end

  # Clear request context after test
  def clear_mcp_request
    @mcp_test_team = nil
    @mcp_test_user = nil
    @mcp_test_admin = nil
  end

  # Call a tool class with given arguments
  # @param tool_class [Class] The tool class to instantiate and call
  # @param args [Hash] Arguments to pass to the tool
  # @return [Hash, String] The tool result
  def call_tool(tool_class, **args)
    tool = tool_class.new

    # Inject headers for authentication (fast-mcp uses lowercase with dashes)
    headers = {}
    headers["x-api-key"] = @mcp_test_team.api_key if @mcp_test_team&.api_key
    headers["x-user-email"] = @mcp_test_user.email if @mcp_test_user&.email

    # Override headers method on this instance
    tool.define_singleton_method(:headers) { headers }

    tool.call(**args)
  end

  # Call a resource class with given parameters
  # @param resource_class [Class] The resource class to instantiate
  # @param params [Hash] Parameters to pass to content method
  # @return [String] The resource content (JSON string)
  def call_resource(resource_class, **params)
    resource = resource_class.new
    if params.empty?
      resource.content
    else
      resource.content(**params)
    end
  end

  # Parse JSON response from resource
  # @param json_string [String] JSON string to parse
  # @return [Hash] Parsed JSON
  def parse_resource(json_string)
    JSON.parse(json_string, symbolize_names: true)
  end
end

# Base test case for MCP tool tests
class McpToolTestCase < ActiveSupport::TestCase
  include McpTestHelper

  teardown do
    clear_mcp_request
  end
end

# Base test case for MCP resource tests
class McpResourceTestCase < ActiveSupport::TestCase
  include McpTestHelper

  teardown do
    clear_mcp_request
  end
end
