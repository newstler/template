class CreateTeamLanguages < ActiveRecord::Migration[8.2]
  def change
    create_table :team_languages, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :team, null: false, foreign_key: true, type: :string
      t.references :language, null: false, foreign_key: true, type: :string
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :team_languages, [ :team_id, :language_id ], unique: true
  end
end
