class ConversationParticipant < ApplicationRecord
  belongs_to :conversation
  belongs_to :user

  validates :user_id, uniqueness: { scope: :conversation_id }

  def mark_as_read!
    update!(last_read_at: Time.current)
  end

  def mark_as_notified!
    update!(last_notified_at: Time.current)
  end

  def unread_since
    [ last_read_at, last_notified_at ].compact.max
  end
end
