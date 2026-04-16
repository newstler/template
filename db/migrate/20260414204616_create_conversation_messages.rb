class CreateConversationMessages < ActiveRecord::Migration[8.2]
  def change
    create_table :conversation_messages, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :conversation, null: false, foreign_key: true, type: :string
      t.references :user, null: false, foreign_key: true, type: :string
      t.text :content
      t.json :body_translations, null: false, default: {}
      t.datetime :flagged_at
      t.string :flag_reason
      t.timestamps
    end
  end
end
