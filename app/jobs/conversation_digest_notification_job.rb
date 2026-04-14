class ConversationDigestNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ConversationMessage.find_by(id: message_id)
    return unless message

    recipients = message.conversation.participants.where.not(id: message.user_id)

    recipients.each do |recipient|
      participant = message.conversation.conversation_participants.find_by(user: recipient)
      next unless participant
      next if participant.last_notified_at.present? && participant.last_notified_at > 5.minutes.ago

      ConversationMailer.with(
        recipient: recipient,
        conversations: [ message.conversation ]
      ).messages_digest.deliver_later

      participant.mark_as_notified!
    end
  end
end
