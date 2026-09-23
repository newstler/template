require "test_helper"

class RubyLlmV2UpgradeTest < ActiveSupport::TestCase
  test "schema is on the RubyLLM 2.0 layout" do
    connection = ActiveRecord::Base.connection
    assert connection.table_exists?(:ruby_llm_models)
    assert connection.table_exists?(:ruby_llm_usages)
    assert connection.column_exists?(:chats, :ruby_llm_model_id)
    assert_not connection.table_exists?(:models)
  end

  test "usage rows get uuid7 primary keys" do
    usage = chats(:one).ruby_llm_usages.create!(operation: "chat", provider: "openai", model: "gpt-4", status: "succeeded")
    assert_match(/\A\h{8}-\h{4}-7\h{3}-/, usage.id)
  end
end
