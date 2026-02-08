class AddReferencesToChatsToolCallsAndMessages < ActiveRecord::Migration[8.2]
  def change
    add_reference :chats, :model, type: :string, foreign_key: true
    add_reference :tool_calls, :message, type: :string, null: false, foreign_key: true
    add_reference :messages, :chat, type: :string, null: false, foreign_key: true
    add_reference :messages, :model, type: :string, foreign_key: true
    add_reference :messages, :tool_call, type: :string, foreign_key: true
  end
end
