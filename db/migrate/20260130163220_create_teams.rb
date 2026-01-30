class CreateTeams < ActiveRecord::Migration[8.2]
  def change
    create_table :teams, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :teams, :slug, unique: true
  end
end
