# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Billing
  class CreateCheckoutToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @admin = users(:one)
    end

    test "rejects non-admin member" do
      team_two = teams(:two)
      mock_mcp_request(team: team_two, user: @admin)

      result = call_tool(Billing::CreateCheckoutTool,
        price_id: "price_123",
        success_url: "http://example.com/success",
        cancel_url: "http://example.com/cancel")

      assert_not result[:success]
      assert_equal "forbidden", result[:code]
    end

    test "requires authentication" do
      assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Billing::CreateCheckoutTool,
          price_id: "price_123",
          success_url: "http://example.com/success",
          cancel_url: "http://example.com/cancel")
      end
    end
  end
end
