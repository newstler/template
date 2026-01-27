class CreateMessages < ActiveRecord::Migration[8.2]
  def change
    create_table :messages, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "uuid7()" }
      t.string :role, null: false
      t.text :content
      t.json :content_raw
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :cached_tokens
      t.integer :cache_creation_tokens
      t.timestamps
    end

    add_index :messages, :role
  end
end
