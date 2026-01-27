class RemoveCircularForeignKeyOnMessagesToolCall < ActiveRecord::Migration[8.2]
  def change
    remove_foreign_key :messages, :tool_calls
  end
end
