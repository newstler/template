require "test_helper"

class ConversationParticipantTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(title: "Test")
    @conversation.conversation_teams.create!(team: teams(:one))
    @user = users(:one)
  end

  test "cannot have two participants for the same user in a conversation" do
    ConversationParticipant.create!(conversation: @conversation, user: @user)
    duplicate = ConversationParticipant.new(conversation: @conversation, user: @user)
    assert_not duplicate.valid?
  end

  test "mark_as_read! sets last_read_at" do
    participant = ConversationParticipant.create!(conversation: @conversation, user: @user)
    assert_nil participant.last_read_at
    participant.mark_as_read!
    assert_not_nil participant.reload.last_read_at
  end

  test "mark_as_notified! sets last_notified_at" do
    participant = ConversationParticipant.create!(conversation: @conversation, user: @user)
    participant.mark_as_notified!
    assert_not_nil participant.reload.last_notified_at
  end

  test "unread_since returns the later of last_read_at and last_notified_at" do
    participant = ConversationParticipant.create!(conversation: @conversation, user: @user)
    earlier = 2.hours.ago
    later = 1.hour.ago
    participant.update!(last_read_at: earlier, last_notified_at: later)
    assert_in_delta later.to_f, participant.unread_since.to_f, 1.0
  end
end
