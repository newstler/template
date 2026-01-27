class CreateAdmins < ActiveRecord::Migration[8.2]
  def change
    create_table :admins, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :email

      t.timestamps
    end
    add_index :admins, :email, unique: true
  end
end
