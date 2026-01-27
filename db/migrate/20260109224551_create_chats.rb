class CreateChats < ActiveRecord::Migration[8.2]
  def change
    create_table :chats, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "uuid7()" }
      t.timestamps
    end
  end
end
