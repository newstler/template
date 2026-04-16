class RenamePublicChatsToAiChatsEnabled < ActiveRecord::Migration[8.2]
  def change
    rename_column :settings, :public_chats, :ai_chats_enabled
  end
end
