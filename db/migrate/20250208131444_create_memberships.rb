class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
      t.references :user, foreign_key: true # Optional because of tombstones
      t.references :team, null: false, foreign_key: true
      t.references :added_by, foreign_key: { to_table: :memberships }
      t.references :platform_agent_of, foreign_key: { to_table: :teams }, optional: true
      t.integer :role, default: 0, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.timestamps

      t.index %i[user_id team_id], unique: true, where: 'user_id IS NOT NULL'
    end
  end
end
