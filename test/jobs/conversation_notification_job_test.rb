require "test_helper"

class ConversationNotificationJobTest < ActiveJob::TestCase
  test "sends a new-message email to each other participant" do
    message = conversation_messages(:first)
    assert_emails 1 do
      perform_enqueued_jobs do
        ConversationNotificationJob.perform_now(message.id)
      end
    end
  end
end
