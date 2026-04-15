class AddDigestWindowToConversationsAndSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :conversation_participants, :pending_notification_at, :datetime
    add_index :conversation_participants, :pending_notification_at

    add_column :settings, :conversation_digest_window_minutes, :integer, default: 5, null: false
  end
end
