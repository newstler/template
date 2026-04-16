require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @user_message = messages(:user_message)
    @assistant_message = messages(:assistant_message)
  end

  test "assistant? is true only for assistant role" do
    assert @assistant_message.assistant?
    assert_not @user_message.assistant?
  end

  test "formats cost for display" do
    @assistant_message.update!(cost: 0.0012)
    assert_equal "$0.0012", @assistant_message.formatted_cost
  end

  test "formatted cost uses <$0.0001 for tiny costs" do
    @assistant_message.update!(cost: 0.00001)
    assert_equal "<$0.0001", @assistant_message.formatted_cost
  end

  test "formatted cost returns nil when zero" do
    message = Message.create!(
      chat: chats(:one),
      role: "user",
      content: "Test",
      cost: 0
    )
    assert_nil message.formatted_cost
  end

  test "first user message sets the chat's first_user_message_preview" do
    chat = chats(:one)
    chat.messages.destroy_all
    chat.update_columns(first_user_message_preview: nil)

    Message.create!(chat: chat, role: "user", content: "Hello there, world")
    assert_equal "Hello there, world", chat.reload.first_user_message_preview
  end

  test "subsequent user messages do not overwrite the preview" do
    chat = chats(:one)
    chat.messages.destroy_all
    chat.update_columns(first_user_message_preview: nil)

    Message.create!(chat: chat, role: "user", content: "First")
    Message.create!(chat: chat, role: "user", content: "Second")
    assert_equal "First", chat.reload.first_user_message_preview
  end

  test "assistant messages do not set the preview" do
    chat = chats(:one)
    chat.messages.destroy_all
    chat.update_columns(first_user_message_preview: nil)

    Message.create!(chat: chat, role: "assistant", content: "I am a bot")
    assert_nil chat.reload.first_user_message_preview
  end

  test "calculates cost from model pricing and token usage" do
    message = Message.create!(
      chat: chats(:one),
      role: "assistant",
      content: "Test",
      input_tokens: 1000,
      output_tokens: 500,
      model: models(:gpt4)
    )

    # GPT-4 fixture pricing: $30/M input, $60/M output
    # 1000 input → 30 * (1000/1000) * 0.001 = 0.03 (confirmed by implementation)
    # 500 output → 60 * (500/1000) * 0.001 = 0.03
    # total = 0.06
    assert_in_delta 0.06, message.cost, 0.0001
  end
end
