class ConversationParticipant < ApplicationRecord
  belongs_to :conversation
  belongs_to :user

  validates :user_id, uniqueness: { scope: :conversation_id }

  # Participants with a pending notification that has aged past the
  # digest window are due for a sweep email.
  scope :due_for_digest, ->(window) {
    where.not(pending_notification_at: nil)
      .where("pending_notification_at <= ?", window.ago)
  }

  def mark_as_read!
    update!(last_read_at: Time.current)
  end

  def mark_as_notified!
    update!(last_notified_at: Time.current, pending_notification_at: nil)
  end

  def unread_since
    [ last_read_at, last_notified_at ].compact.max
  end
end
