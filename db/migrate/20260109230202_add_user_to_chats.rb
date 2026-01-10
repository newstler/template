class AddUserToChats < ActiveRecord::Migration[8.2]
  def change
    add_reference :chats, :user, null: false, foreign_key: true, type: :string
  end
end
