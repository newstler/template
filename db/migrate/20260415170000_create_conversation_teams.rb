class CreateConversationTeams < ActiveRecord::Migration[8.0]
  def up
    create_table :conversation_teams, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :conversation, null: false, foreign_key: true, type: :string
      t.references :team, null: false, foreign_key: true, type: :string
      t.timestamps
    end

    add_index :conversation_teams, [ :conversation_id, :team_id ], unique: true

    # Backfill: every existing conversation's team_id becomes a row here.
    execute <<~SQL.squish
      INSERT INTO conversation_teams (id, conversation_id, team_id, created_at, updated_at)
      SELECT uuid7(), id, team_id, datetime('now'), datetime('now')
      FROM conversations
      WHERE team_id IS NOT NULL
    SQL

    remove_reference :conversations, :team, foreign_key: true, type: :string
  end

  def down
    add_reference :conversations, :team, foreign_key: true, type: :string

    # Restore conversation.team_id from the first conversation_team row.
    execute <<~SQL.squish
      UPDATE conversations
      SET team_id = (
        SELECT team_id FROM conversation_teams
        WHERE conversation_teams.conversation_id = conversations.id
        LIMIT 1
      )
    SQL

    drop_table :conversation_teams
  end
end
