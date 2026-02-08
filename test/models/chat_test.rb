require "test_helper"

class ChatTest < ActiveSupport::TestCase
  setup do
    @chat = chats(:one)
  end

  test "belongs to user" do
    assert_equal users(:one), @chat.user
  end

  test "belongs to model" do
    assert_equal models(:gpt4), @chat.model
  end

  test "calculates total cost from messages" do
    # Chat one has messages with costs
    assert_kind_of Numeric, @chat.total_cost
  end

  test "formats total cost for display" do
    chat = chats(:one)
    # Set a specific cost on the chat to test formatting
    chat.update_column(:total_cost, 0.0012)

    formatted = chat.formatted_total_cost
    assert_not_nil formatted
    assert_match(/\$\d+\.\d+/, formatted)
  end

  test "formatted total cost returns nil when zero" do
    chat = Chat.create!(user: users(:two), model: models(:claude))
    assert_nil chat.formatted_total_cost
  end
end
