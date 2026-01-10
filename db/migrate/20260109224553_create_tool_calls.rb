class CreateToolCalls < ActiveRecord::Migration[8.2]
  def change
    create_table :tool_calls, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
      t.string :tool_call_id, null: false
      t.string :name, null: false

      t.json :arguments, default: {}

      t.timestamps
    end

    add_index :tool_calls, :tool_call_id, unique: true
    add_index :tool_calls, :name
  end
end
