class ConversationDigestNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    # Full implementation in Plan 02 Task 8
  end
end
