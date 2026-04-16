class AddFirstUserMessagePreviewToChats < ActiveRecord::Migration[8.2]
  def change
    add_column :chats, :first_user_message_preview, :string
  end
end
