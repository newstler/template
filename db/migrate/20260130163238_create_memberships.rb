class CreateMemberships < ActiveRecord::Migration[8.2]
  def change
    create_table :memberships, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :user, null: false, foreign_key: true, type: :string
      t.references :team, null: false, foreign_key: true, type: :string
      t.references :invited_by, foreign_key: { to_table: :users }, type: :string
      t.string :role, null: false, default: "member"

      t.timestamps
    end

    add_index :memberships, [ :user_id, :team_id ], unique: true
  end
end
