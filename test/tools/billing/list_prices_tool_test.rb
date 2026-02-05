# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Billing
  class ListPricesToolTest < McpToolTestCase
    test "returns prices without authentication" do
      original_method = Price.method(:all)
      Price.define_singleton_method(:all) do
        [ Price.new(id: "price_1", product_name: "Pro", unit_amount: 1900, currency: "usd", interval: "month", interval_count: 1) ]
      end

      result = call_tool(Billing::ListPricesTool)

      assert result[:success]
      assert_equal 1, result[:data].size
      assert_equal "Pro", result[:data].first[:product_name]
      assert_equal "$19.00", result[:data].first[:amount]
      assert_equal "per month", result[:data].first[:interval]
    ensure
      Price.define_singleton_method(:all, original_method)
    end
  end
end
