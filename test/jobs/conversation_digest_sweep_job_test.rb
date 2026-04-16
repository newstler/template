require "test_helper"

class ConversationDigestSweepJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @conversation = conversations(:one)
    @sender = users(:one)
    @recipient = users(:two)
    @participant = conversation_participants(:one_two)
    @participant.update!(pending_notification_at: nil, last_notified_at: nil)
  end

  test "creating multiple messages in one window produces one digest email per participant" do
    5.times do |i|
      ConversationMessage.create!(conversation: @conversation, user: @sender, content: "Msg #{i}")
    end

    # Advance past the digest window so the sweep picks the participant up.
    travel 6.minutes do
      assert_emails 1 do
        perform_enqueued_jobs do
          ConversationDigestSweepJob.perform_now
        end
      end
    end

    @participant.reload
    assert_nil @participant.pending_notification_at
    assert_not_nil @participant.last_notified_at
  end

  test "participants inside the digest window are not swept yet" do
    @participant.update!(pending_notification_at: 1.minute.ago)

    assert_emails 0 do
      perform_enqueued_jobs do
        ConversationDigestSweepJob.perform_now
      end
    end

    assert_not_nil @participant.reload.pending_notification_at
  end

  test "a new message after a digest triggers a fresh cycle" do
    ConversationMessage.create!(conversation: @conversation, user: @sender, content: "First")

    travel 6.minutes
    perform_enqueued_jobs do
      ConversationDigestSweepJob.perform_now
    end
    assert_nil @participant.reload.pending_notification_at
    assert_not_nil @participant.last_notified_at

    travel 10.minutes
    ConversationMessage.create!(conversation: @conversation, user: @sender, content: "Second")
    assert_not_nil @participant.reload.pending_notification_at

    travel 6.minutes
    assert_emails 1 do
      perform_enqueued_jobs do
        ConversationDigestSweepJob.perform_now
      end
    end
  end
end
