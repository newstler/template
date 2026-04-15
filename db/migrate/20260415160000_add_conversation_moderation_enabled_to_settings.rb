class AddConversationModerationEnabledToSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :settings, :conversation_moderation_enabled, :boolean, default: true, null: false
  end
end
