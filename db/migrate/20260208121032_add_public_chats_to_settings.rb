class AddPublicChatsToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :public_chats, :boolean, default: true, null: false
  end
end
