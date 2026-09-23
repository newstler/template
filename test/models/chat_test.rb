require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "belongs to a RubyLLM registry model" do
    assert_instance_of RubyLLM::ActiveRecord::Model, chats(:one).model
    assert_equal "gpt-4", chats(:one).model_id
  end

  test "cost comes from recorded usages" do
    assert_in_delta 0.0012, chats(:one).cost.total
  end
end
