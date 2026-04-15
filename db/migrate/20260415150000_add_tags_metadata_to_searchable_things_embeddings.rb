class AddTagsMetadataToSearchableThingsEmbeddings < ActiveRecord::Migration[8.2]
  # SQLite vec0 tables can't be ALTERed — drop and recreate with an
  # additional metadata column that filter_by can target. Uses a
  # partition key so vec0's KNN query accepts WHERE constraints on it.
  def up
    drop_virtual_table :searchable_things_embeddings, :vec0, []
    create_virtual_table :searchable_things_embeddings, :vec0, [
      "tags text partition key",
      "id text primary key",
      "embedding float[1536] distance_metric=cosine",
      "source_hash text"
    ]
  end

  def down
    drop_virtual_table :searchable_things_embeddings, :vec0, []
    create_virtual_table :searchable_things_embeddings, :vec0, [
      "id text primary key",
      "embedding float[1536] distance_metric=cosine",
      "source_hash text"
    ]
  end
end
