require "test_helper"

class ConversationParticipantTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(team: teams(:one), title: "Test")
    @user = users(:one)
  end

  test "belongs to conversation and user" do
    participant = ConversationParticipant.create!(conversation: @conversation, user: @user)
    assert_equal @conversation, participant.conversation
    assert_equal @user, participant.user
  end

  test "is unique per conversation+user" do
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

  test "unread_since returns the latest of read and notified timestamps" do
    participant = ConversationParticipant.create!(conversation: @conversation, user: @user)
    time_a = 2.hours.ago
    time_b = 1.hour.ago
    participant.update!(last_read_at: time_a, last_notified_at: time_b)
    assert_in_delta time_b.to_f, participant.unread_since.to_f, 1.0
  end
end
