# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

class AvailableModelsResourceTest < McpResourceTestCase
  test "returns models without authentication" do
    result = parse_resource(call_resource(Mcp::AvailableModelsResource))

    assert result[:models_count].present? || result[:models_count] == 0
    assert_kind_of Array, result[:models]
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

  test "includes configured providers" do
    result = parse_resource(call_resource(Mcp::AvailableModelsResource))

    assert result.key?(:providers)
    assert_kind_of Array, result[:providers]
  end
end
