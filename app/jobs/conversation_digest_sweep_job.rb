class ConversationDigestSweepJob < ApplicationJob
  queue_as :default

  # Runs on a recurring schedule. Finds participants whose earliest
  # pending notification has aged past the digest window and sends one
  # digest email each (grouped by conversation).
  def perform
    window = Setting.conversation_digest_window_minutes.minutes

    ConversationParticipant
      .due_for_digest(window)
      .includes(:user, conversation: :conversation_messages)
      .find_each do |participant|
        deliver_digest(participant)
      end
  end

  private

  def deliver_digest(participant)
    recipient = participant.user
    conversation = participant.conversation

    since = [ participant.last_notified_at, participant.last_read_at ].compact.max
    scope = conversation.conversation_messages.where.not(user_id: recipient.id)
    scope = scope.where("created_at > ?", since) if since

    return participant.update!(pending_notification_at: nil) if scope.none?

    ConversationMailer.with(
      recipient: recipient,
      conversations: [ conversation ]
    ).messages_digest.deliver_later

    participant.mark_as_notified!
  end
end
