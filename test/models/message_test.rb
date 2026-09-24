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

  test "exposes tokens and cost from its usage" do
    assert_equal 10, @assistant_message.tokens.input
    assert_equal 15, @assistant_message.tokens.output
    assert_in_delta 0.0012, @assistant_message.cost.total
  end

  test "exposes tool calls from the gem table" do
    assert_equal "search", @assistant_message.tool_calls.values.first.name
  end
end
