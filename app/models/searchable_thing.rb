# Demo / test model for the Searchable concern. Safe to delete in consuming
# apps that don't need a demonstration; kept in the template for testing.
class SearchableThing < ApplicationRecord
  include Searchable
  searchable_fields :name, :description, :tags
end
