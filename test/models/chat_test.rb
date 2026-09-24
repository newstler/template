require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "belongs to a RubyLLM registry model" do
    assert_instance_of RubyLLM::ActiveRecord::Model, chats(:one).model
    assert_equal "gpt-4", chats(:one).model_id
  end

  test "cost comes from recorded usages" do
    assert_in_delta 0.0012, chats(:one).cost.total
  end

  test "with_usage_cost treats unpriced attempts as zero" do
    chats(:one).ruby_llm_usages.create!(operation: "chat", provider: "openai", model: "gpt-4", status: "failed")
    assert_in_delta 0.0012, Chat.with_usage_cost.find(chats(:one).id).usage_cost
  end
end
