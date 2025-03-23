class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
      t.string :name, null: false
      t.string :time_zone, null: false
      t.timestamps
    end
  end
end
