# Searchable: SQLite FTS5-backed full-text search for ActiveRecord models.
#
# Usage:
#   class Candidate < ApplicationRecord
#     include Searchable
#     searchable_fields :profession, :skills, :notes
#   end
#
#   Candidate.search("welder russian speaker")
#
# Install the FTS virtual table with the generator:
#   bin/rails generate searchable:install Candidate profession skills notes
#
# Limitations (acceptable at template scale):
#   - Two-step lookup (FTS ids → records) rather than a single JOIN so the
#     result stays compatible with string primary keys.
#   - No phrase queries unless the user escapes quotes.
#   - No facets (compose with .where scopes instead).
#
# For larger apps, the public API (include, searchable_fields, .search)
# is stable enough to swap to Meilisearch/Typesense underneath.
module Searchable
  extend ActiveSupport::Concern

  class_methods do
    def searchable_fields(*fields)
      @searchable_fields_list = fields.map(&:to_sym)
      after_save_commit :update_search_index
      after_destroy_commit :remove_from_search_index
    end

    def searchable_fields_list
      @searchable_fields_list || []
    end

    def searchable_table_name
      "#{table_name}_fts"
    end

    # Returns an ActiveRecord::Relation of records matching the FTS5 query,
    # ordered by bm25 relevance. Composable with .where / .limit / .includes.
    def search(query)
      return none if query.blank?

      sanitized = sanitize_fts_query(query)
      return none if sanitized.empty?

      fts = searchable_table_name
      ids = connection.select_values(
        connection.sanitize_sql_array(
          ["SELECT id FROM #{fts} WHERE #{fts} MATCH ? ORDER BY bm25(#{fts})", sanitized]
        )
      )

      return none if ids.empty?

      where(id: ids).in_order_of(:id, ids)
    end

    # Rewrites a user query into something FTS5 can parse. Strips quotes,
    # collapses whitespace, and wraps the result so stray operators don't
    # trigger a "malformed MATCH expression" error.
    def sanitize_fts_query(query)
      cleaned = query.to_s.gsub(/["']/, " ").gsub(/\s+/, " ").strip
      return "" if cleaned.empty?

      # Wrap each token in double quotes so FTS5 treats them as literals.
      cleaned.split(" ").map { |token| %("#{token}") }.join(" ")
    end
  end

  def update_search_index
    fields = self.class.searchable_fields_list
    return if fields.empty?

    fts = self.class.searchable_table_name
    columns = (["id"] + fields.map(&:to_s)).join(", ")
    placeholders = (["?"] * (fields.length + 1)).join(", ")
    values = [id] + fields.map { |f| public_send(f).to_s }

    sql = self.class.connection.sanitize_sql_array(
      ["INSERT OR REPLACE INTO #{fts} (#{columns}) VALUES (#{placeholders})"] + values
    )
    self.class.connection.execute(sql)
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[Searchable] index update failed for #{self.class.name}##{id}: #{e.message}")
  end

  def remove_from_search_index
    fts = self.class.searchable_table_name
    sql = self.class.connection.sanitize_sql_array(
      ["DELETE FROM #{fts} WHERE id = ?", id]
    )
    self.class.connection.execute(sql)
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[Searchable] index delete failed for #{self.class.name}##{id}: #{e.message}")
  end
end
