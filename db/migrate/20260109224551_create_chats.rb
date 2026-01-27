class CreateChats < ActiveRecord::Migration[8.2]
  def change
    create_table :chats, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.timestamps
    end
  end
end
