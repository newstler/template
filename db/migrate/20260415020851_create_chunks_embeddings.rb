class CreateChunksEmbeddings < ActiveRecord::Migration[8.2]
  # Uses create_virtual_table so Rails' schema dumper can round-trip the vec0
  # definition into schema.rb on db:migrate.
  def up
    create_virtual_table :chunks_embeddings, :vec0, [
      "id text primary key",
      "embedding float[1536] distance_metric=cosine",
      "source_hash text"
    ]
  end

  def down
    drop_virtual_table :chunks_embeddings, :vec0, []
  end
end
