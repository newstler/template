require "test_helper"

class ToolCallTest < ActiveSupport::TestCase
  setup do
    @tool_call = tool_calls(:search_call)
  end

  test "belongs to message" do
    assert_equal messages(:assistant_message), @tool_call.message
  end

  test "has required attributes" do
    assert @tool_call.tool_call_id.present?
    assert @tool_call.name.present?
  end

  test "has arguments hash" do
    assert_kind_of Hash, @tool_call.arguments
    assert_equal "weather in Paris", @tool_call.arguments["query"]
  end
end
