class CreateArticlesFtsAndEmbeddings < ActiveRecord::Migration[8.2]
  def up
    create_virtual_table :articles_fts, :fts5, [
      "id UNINDEXED",
      "title",
      "tokenize='porter unicode61 remove_diacritics 2'"
    ]

    execute(
      "INSERT INTO articles_fts (id, title) " \
      "SELECT id, title FROM articles"
    )

    create_virtual_table :articles_embeddings, :vec0, [
      "id text primary key",
      "embedding float[1536] distance_metric=cosine",
      "source_hash text"
    ]
  end

  def down
    drop_virtual_table :articles_embeddings, :vec0, []
    drop_virtual_table :articles_fts, :fts5, []
  end
end
