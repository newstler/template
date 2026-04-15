require "test_helper"

class ToolCallTest < ActiveSupport::TestCase
  test "stores arguments as a hash" do
    tool_call = tool_calls(:search_call)
    assert_kind_of Hash, tool_call.arguments
    assert_equal "weather in Paris", tool_call.arguments["query"]
  end
end
