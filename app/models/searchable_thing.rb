# Demo / test model for the Searchable, Embeddable, and Chunkable
# concerns. Safe to delete in consuming apps that don't need a
# demonstration; kept in the template for testing.
class SearchableThing < ApplicationRecord
  include Searchable
  include Embeddable
  include HybridSearchable
  include Chunkable

  searchable_fields :name, :description, :tags

  embeddable_source ->(record) { "#{record.name} #{record.description} #{record.tags}".strip }
  embeddable_model  -> { Setting.embedding_model }
  embeddable_distance :cosine

  chunk_source ->(record) { record.description.to_s }
  chunk_size 10
  chunk_overlap 2
end
