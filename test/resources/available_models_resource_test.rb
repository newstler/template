# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

class AvailableModelsResourceTest < McpResourceTestCase
  test "returns models payload without authentication" do
    result = parse_resource(call_resource(Mcp::AvailableModelsResource))

    assert_kind_of Integer, result[:models_count]
    assert_kind_of Array, result[:models]
    assert_equal result[:models_count], result[:models].length
    assert_kind_of Array, result[:providers]
  end

  test "includes model details when models exist" do
    skip "No models configured in test environment" if Model.enabled.none?

    result = parse_resource(call_resource(Mcp::AvailableModelsResource))

    model = result[:models].first
    assert model[:id].present?
    assert model[:model_id].present?
    assert model[:name].present?
    assert model[:provider].present?
  end
end
