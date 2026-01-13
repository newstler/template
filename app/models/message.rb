class Message < ApplicationRecord
  acts_as_message tool_calls_foreign_key: :message_id
  has_many_attached :attachments
  broadcasts_to ->(message) { "chat_#{message.chat_id}" }, inserts_by: :append, target: "messages"

  after_update_commit :broadcast_message_replacement, if: :assistant?

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

  def broadcast_message_replacement
    broadcast_replace_to "chat_#{chat_id}",
      target: "message_#{id}",
      partial: "messages/message",
      locals: { message: self }
  end
end
