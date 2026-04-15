require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "has many conversation_messages ordered chronologically" do
    conversation = Conversation.create!(team: teams(:one), title: "Test")
    user = users(:one)
    ConversationParticipant.create!(conversation: conversation, user: user)

    old = conversation.conversation_messages.create!(user: user, content: "old", created_at: 1.day.ago)
    new_msg = conversation.conversation_messages.create!(user: user, content: "new")

    assert_equal [ old, new_msg ], conversation.conversation_messages.chronologically.to_a
  end
end
