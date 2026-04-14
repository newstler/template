class CreateConversationParticipants < ActiveRecord::Migration[8.2]
  def change
    create_table :conversation_participants, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :conversation, null: false, foreign_key: true, type: :string
      t.references :user, null: false, foreign_key: true, type: :string
      t.datetime :last_read_at
      t.datetime :last_notified_at
      t.timestamps
    end
    add_index :conversation_participants, [ :conversation_id, :user_id ], unique: true
  end
end
