class Message < ApplicationRecord
  acts_as_message

  has_many_attached :attachments
  broadcasts_to ->(message) { "chat_#{message.chat_id}" }, inserts_by: :append, target: "messages"

  after_update_commit :broadcast_message_replacement, if: :assistant?

  # Update counter caches
  after_create :increment_counters
  after_create_commit :update_chat_preview_if_first_user_message
  after_destroy :decrement_counters

  def broadcast_append_chunk(content)
    broadcast_append_to "chat_#{chat_id}",
      target: "message_#{id}_content",
      partial: "messages/content",
      locals: { content: content }
  end

  def assistant?
    role == "assistant"
  end

  private

  def increment_counters
    return unless chat

    Chat.increment_counter(:messages_count, chat.id)
  end

  def decrement_counters
    return unless chat

    Chat.decrement_counter(:messages_count, chat.id)
  end

  def broadcast_message_replacement
    broadcast_replace_to "chat_#{chat_id}",
      target: "message_#{id}",
      partial: "messages/message",
      locals: { message: self }
  end

  # Denormalize the first user message onto the chat so the sidebar
  # can render its title without loading messages.
  def update_chat_preview_if_first_user_message
    return unless role == "user"
    return unless chat
    return if chat.first_user_message_preview.present?
    return if content.blank?

    chat.update_columns(first_user_message_preview: content.to_s[0, 80])
  end
end
