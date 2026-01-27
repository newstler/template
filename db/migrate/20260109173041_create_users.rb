class CreateUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :users, force: true, id: {type: :string, default: -> { "uuid7()" }} do |t|
      t.primary_key :id, :string, default: -> { "uuid7()" }
      t.string :email
      t.string :name

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
