class ConversationMessage < ApplicationRecord
  belongs_to :conversation, touch: true
  belongs_to :user

  has_many_attached :attachments

  scope :chronologically, -> { order(created_at: :asc) }

  validate :content_or_attachments_present

  after_create_commit :broadcast_append_to_conversation
  after_create_commit :schedule_digest_notifications

  def body_for(recipient)
    return content unless recipient&.locale.present?
    body_translations[recipient.locale.to_s] || content
  end

  def visible_to?(user)
    flagged_at.blank? || user == self.user
  end

  private

  def content_or_attachments_present
    return if content.present? || attachments.attached?
    errors.add(:base, :content_or_attachments_required)
  end

  def broadcast_append_to_conversation
    broadcast_append_to conversation,
                        target: "conversation_messages",
                        partial: "teams/conversations/conversation_message",
                        locals: { message: self }
  end

  def schedule_digest_notifications
    ConversationDigestNotificationJob.set(wait: 2.minutes).perform_later(id)
  end
end
