# Demo / test model for the Searchable and Embeddable concerns. Safe
# to delete in consuming apps that don't need a demonstration; kept in
# the template for testing.
class SearchableThing < ApplicationRecord
  include Searchable
  include Embeddable

  searchable_fields :name, :description, :tags

  embeddable_source ->(record) { "#{record.name} #{record.description} #{record.tags}".strip }
  embeddable_model  -> { Setting.embedding_model }
  embeddable_distance :cosine
end
