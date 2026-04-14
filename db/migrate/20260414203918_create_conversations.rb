class CreateConversations < ActiveRecord::Migration[8.2]
  def change
    create_table :conversations, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :team, null: false, foreign_key: true, type: :string
      t.references :subject, polymorphic: true, null: true, type: :string
      t.string :title
      t.timestamps
    end
  end
end
