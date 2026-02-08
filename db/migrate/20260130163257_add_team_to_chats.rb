class AddTeamToChats < ActiveRecord::Migration[8.2]
  def change
    add_reference :chats, :team, null: true, foreign_key: true, type: :string
  end
end
