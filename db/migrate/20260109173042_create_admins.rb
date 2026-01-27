class CreateAdmins < ActiveRecord::Migration[8.2]
  def change
    create_table :admins, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "uuid7()" }
      t.string :email

      t.timestamps
    end
    add_index :admins, :email, unique: true
  end
end
