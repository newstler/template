class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations, force: true, id: false do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :token, null: false
      t.references :team, null: false, foreign_key: true
      t.references :membership, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :memberships }
      t.datetime :expires_at
      t.datetime :claimed_at
      t.timestamps

      t.index :token, unique: true
      t.index %i[email team_id], unique: true, where: 'claimed_at IS NULL'
    end
  end
end
