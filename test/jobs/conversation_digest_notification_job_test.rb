require "test_helper"

class ConversationDigestNotificationJobTest < ActiveJob::TestCase
  test "sends a digest email to each other participant" do
    message = conversation_messages(:first)
    assert_emails 1 do
      perform_enqueued_jobs do
        ConversationDigestNotificationJob.perform_now(message.id)
      end
    end
  end

  test "skips recipients notified in the last 5 minutes" do
    message = conversation_messages(:first)
    participant = message.conversation.conversation_participants.where.not(user: message.user).first
    participant.update!(last_notified_at: 2.minutes.ago)

    assert_emails 0 do
      perform_enqueued_jobs do
        ConversationDigestNotificationJob.perform_now(message.id)
      end
    end
  end
end
