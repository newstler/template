class AddChunksSourceDigestToSearchableThings < ActiveRecord::Migration[8.2]
  def change
    add_column :searchable_things, :chunks_source_digest, :string
  end
end
