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
# Tested combinations:
#   - insert / update / destroy callbacks keep the FTS table in sync
#   - Cyrillic content (Сварщик)
#   - Turkish diacritics via remove_diacritics 2 (Çilingir → "cilingir")
#   - Composability with .where scopes and pagination
#
# Limitations (acceptable at template scale):
#   - Two-step lookup (FTS ids → records) rather than a single JOIN so the
#     result stays compatible with string primary keys.
#   - No phrase queries unless the user escapes quotes — the concern
#     sanitizes stray quotes into whitespace to avoid "malformed MATCH".
#   - No facets (compose with .where scopes instead; FTS5 has no native
#     support for aggregate facets anyway).
#   - Aggregate cross-model ranking not supported — each model has its
#     own FTS5 table and bm25 is computed per-table.
#
# For larger apps, the public API (include, searchable_fields, .search)
# is stable enough to swap to Meilisearch/Typesense underneath without
# touching call sites.
module Searchable
  extend ActiveSupport::Concern

  def self.registry
    @registry ||= []
  end

  included do
    Searchable.registry << self unless Searchable.registry.include?(self)
  end

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
    #
    # When called on an outer scope (e.g. Thing.where(team_id: x).search("foo")),
    # the outer ids are pushed into the FTS query so we don't scan every
    # tenant. For very large outer scopes we fall back to post-hoc filtering
    # to stay under SQLite's parameter limit.
    OUTER_SCOPE_PUSHDOWN_LIMIT = 5_000

    def search(query)
      return none if query.blank?

      sanitized = sanitize_fts_query(query)
      return none if sanitized.empty?

      fts = searchable_table_name
      scope = current_scope
      outer_ids = if scope && scope.where_clause.any?
        scope.unscope(:order, :limit, :offset).pluck(:id)
      end

      if outer_ids && outer_ids.size <= OUTER_SCOPE_PUSHDOWN_LIMIT
        return none if outer_ids.empty?
        placeholders = (%w[?] * outer_ids.size).join(", ")
        sql = "SELECT id FROM #{fts} WHERE #{fts} MATCH ? AND id IN (#{placeholders}) ORDER BY bm25(#{fts})"
        bindings = [ sanitized ] + outer_ids
      else
        sql = "SELECT id FROM #{fts} WHERE #{fts} MATCH ? ORDER BY bm25(#{fts})"
        bindings = [ sanitized ]
      end

      matched_ids = connection.select_values(send(:sanitize_sql_array, [ sql ] + bindings))
      return none if matched_ids.empty?

      where(id: matched_ids).in_order_of(:id, matched_ids)
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
    columns = ([ "id" ] + fields.map(&:to_s)).join(", ")
    placeholders = ([ "?" ] * (fields.length + 1)).join(", ")
    values = [ id ] + fields.map { |f|
      if self.class.include?(Translatable)
        Mobility.with_locale(:en) { public_send(f).to_s }
      else
        public_send(f).to_s
      end
    }

    # FTS5 auto-generates its own rowid; our string id is a plain UNINDEXED
    # column, so INSERT OR REPLACE can't dedupe by id. Delete then insert.
    conn = self.class.connection
    conn.execute(self.class.send(:sanitize_sql_array, [ "DELETE FROM #{fts} WHERE id = ?", id ]))
    conn.execute(
      self.class.send(:sanitize_sql_array,
        [ "INSERT INTO #{fts} (#{columns}) VALUES (#{placeholders})" ] + values)
    )
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[Searchable] index update failed for #{self.class.name}##{id}: #{e.message}")
  end

  def remove_from_search_index
    fts = self.class.searchable_table_name
    sql = self.class.send(:sanitize_sql_array,
      [ "DELETE FROM #{fts} WHERE id = ?", id ]
    )
    self.class.connection.execute(sql)
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[Searchable] index delete failed for #{self.class.name}##{id}: #{e.message}")
  end
end
