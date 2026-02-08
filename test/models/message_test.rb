require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @user_message = messages(:user_message)
    @assistant_message = messages(:assistant_message)
  end

  test "belongs to chat" do
    assert_equal chats(:one), @user_message.chat
  end

  test "assistant? returns true for assistant messages" do
    assert @assistant_message.assistant?
  end

  test "assistant? returns false for user messages" do
    assert_not @user_message.assistant?
  end

  test "formats cost for display" do
    @assistant_message.update!(cost: 0.0012)
    assert_equal "$0.0012", @assistant_message.formatted_cost
  end

  test "formatted cost shows less than for tiny costs" do
    @assistant_message.update!(cost: 0.00001)
    assert_equal "<$0.0001", @assistant_message.formatted_cost
  end

  test "formatted cost returns nil when zero" do
    # Create a message with no tokens to avoid cost recalculation
    message = Message.create!(
      chat: chats(:one),
      role: "user",
      content: "Test",
      cost: 0
    )
    assert_nil message.formatted_cost
  end

  test "calculates cost based on token usage" do
    message = Message.new(
      chat: chats(:one),
      role: "assistant",
      content: "Test",
      input_tokens: 1000,
      output_tokens: 500,
      model: models(:gpt4)
    )

    message.save!

    # GPT-4 pricing: $30/M input, $60/M output
    # (1000 / 1_000_000) * 30 + (500 / 1_000_000) * 60 = 0.00003 + 0.00003 = 0.00006
    assert message.cost > 0
  end
end
