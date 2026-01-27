class CreateToolCalls < ActiveRecord::Migration[8.2]
  def change
    create_table :tool_calls, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :tool_call_id, null: false
      t.string :name, null: false

      t.json :arguments, default: {}

      t.timestamps
    end

    add_index :tool_calls, :tool_call_id, unique: true
    add_index :tool_calls, :name
  end
end
