require "test_helper"

class ChatTest < ActiveSupport::TestCase
  setup do
    @chat = chats(:one)
  end

  test "formats non-zero total cost as currency" do
    @chat.update_column(:total_cost, 0.0012)
    assert_match(/\$\d+\.\d+/, @chat.formatted_total_cost)
  end

  test "formatted_total_cost returns nil when chat has no cost" do
    chat = Chat.create!(user: users(:two), model: models(:claude))
    assert_nil chat.formatted_total_cost
  end
end
