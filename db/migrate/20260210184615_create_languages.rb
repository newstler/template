class CreateLanguages < ActiveRecord::Migration[8.0]
  def change
    create_table :languages, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :native_name, null: false
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    add_index :languages, :code, unique: true
  end
end
