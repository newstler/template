class CreateChunks < ActiveRecord::Migration[8.2]
  def change
    create_table :chunks, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :chunkable, polymorphic: true, null: false, type: :string
      t.integer :position, null: false
      t.text :content, null: false
      t.timestamps
    end
    add_index :chunks, [ :chunkable_type, :chunkable_id, :position ], unique: true,
      name: "index_chunks_on_chunkable_and_position"
  end
end
