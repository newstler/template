class ConversationNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ConversationMessage.find_by(id: message_id)
    return unless message

    recipients = message.conversation.participants.where.not(id: message.user_id)
    recipients.each do |recipient|
      ConversationMailer.with(message: message, recipient: recipient).new_message.deliver_later
    end
  end
end
