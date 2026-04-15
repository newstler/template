# Embeddable: vector similarity search backed by sqlite-vec.
#
# Usage:
#   class Candidate < ApplicationRecord
#     include Embeddable
#
#     embeddable_source ->(r) { "#{r.profession} #{r.skills} #{r.summary}" }
#     embeddable_model  -> { Setting.embedding_model }
#     embeddable_distance :cosine
#     embeddable_metadata ->(r) { { nationality: r.nationality_code } }
#   end
#
#   Candidate.similar_to("welder with marine experience", limit: 20)
#
# Install the vec0 virtual table with the generator:
#   bin/rails generate embeddable:install Candidate 1536 --metadata nationality
#
# Records are embedded asynchronously via +EmbedRecordJob+. The source
# string is hashed and compared before enqueuing so unchanged records
# aren't re-embedded.
#
# +similar_to+ returns an ActiveRecord::Relation ordered by vec0
# distance (nearest first). Composable with .where / .includes.
# Each returned record exposes +#similarity_distance+ for UI display.
module Embeddable
  extend ActiveSupport::Concern

  class_methods do
    def embeddable_source(proc = nil, &block)
      @embeddable_source = proc || block
    end

    def embeddable_source_proc
      @embeddable_source
    end

    def embeddable_model(proc = nil, &block)
      @embeddable_model_proc = proc || block
    end

    def embeddable_model_name
      (@embeddable_model_proc&.call) || Setting.embedding_model
    end

    def embeddable_distance(metric = nil)
      @embeddable_distance = metric if metric
      @embeddable_distance || :cosine
    end

    def embeddable_metadata(proc = nil, &block)
      @embeddable_metadata = proc || block
    end

    def embeddable_metadata_for(record)
      (@embeddable_metadata&.call(record)) || {}
    end

    def embeddings_table
      "#{table_name}_embeddings"
    end

    # Returns an ActiveRecord::Relation of records ranked by vec0
    # distance ascending (nearest first). Each returned record has a
    # +#similarity_distance+ method for UI display.
    def similar_to(query_text, limit: 20, filter_by: {}, max_distance: nil)
      return none if query_text.blank?

      embedding = embed_query(query_text)
      return none if embedding.blank?

      rows = vec_search(embedding, limit: limit, filter_by: filter_by)
      rows = rows.select { |r| r["distance"].to_f <= max_distance } if max_distance
      return none if rows.empty?

      ids = rows.map { |r| r["id"] }
      distances = rows.to_h { |r| [ r["id"], r["distance"].to_f ] }

      relation = where(id: ids).in_order_of(:id, ids)
      relation.extending(SimilarityDistanceAttachment).tap do |rel|
        rel.instance_variable_set(:@similarity_distances, distances)
      end
    end

    def embed_query(text)
      model = embeddable_model_name
      return nil if model.blank?

      response = RubyLLM.embed(text, model: model)
      AiCost.record!(
        cost_type: "embedding",
        model_id: model,
        input_tokens: response.input_tokens.to_i,
      )
      response.vectors
    rescue StandardError => e
      Rails.logger.warn("[Embeddable] query embed failed: #{e.message}")
      nil
    end

    private

    def vec_search(embedding, limit:, filter_by:)
      vector_literal = "[#{embedding.map(&:to_f).join(',')}]"
      filter_sql = build_filter_sql(filter_by)

      sql = +"SELECT id, distance FROM #{embeddings_table} "
      sql << "WHERE embedding MATCH #{connection.quote(vector_literal)} "
      sql << "AND #{filter_sql} " unless filter_sql.empty?
      sql << "AND k = #{limit.to_i} "
      sql << "ORDER BY distance"

      connection.select_all(sql).to_a
    end

    def build_filter_sql(filters)
      return "" if filters.blank?

      filters.map do |key, value|
        column = connection.quote_column_name(key.to_s)
        case value
        when Range
          "#{column} BETWEEN #{connection.quote(value.begin)} AND #{connection.quote(value.end)}"
        when Array
          quoted = value.map { |v| connection.quote(v) }.join(",")
          "#{column} IN (#{quoted})"
        else
          "#{column} = #{connection.quote(value)}"
        end
      end.join(" AND ")
    end
  end

  # Relation extension that decorates each loaded record with its
  # vec0 distance score (accessible via +#similarity_distance+).
  # Hooks +exec_queries+ rather than +load+ so calling +records+
  # inside the attachment doesn't recurse through +load+.
  module SimilarityDistanceAttachment
    def exec_queries(&)
      loaded_records = super
      distances = @similarity_distances || {}
      loaded_records.each do |record|
        distance = distances[record.id]
        record.define_singleton_method(:similarity_distance) { distance }
      end
      loaded_records
    end
  end

  included do
    after_save_commit :enqueue_embedding_if_changed
    after_destroy_commit :purge_embedding
  end

  def source_for_embedding
    proc = self.class.embeddable_source_proc
    return "" unless proc

    proc.call(self).to_s
  end

  def metadata_for_embedding
    self.class.embeddable_metadata_for(self)
  end

  def embedding_source_hash
    Digest::SHA256.hexdigest(source_for_embedding)
  end

  def stored_embedding_source_hash
    self.class.connection.select_value(
      self.class.send(
        :sanitize_sql_array,
        [ "SELECT source_hash FROM #{self.class.embeddings_table} WHERE id = ?", id ]
      )
    )
  rescue ActiveRecord::StatementInvalid
    nil
  end

  def should_reembed?
    return false if source_for_embedding.blank?

    embedding_source_hash != stored_embedding_source_hash
  end

  def enqueue_embedding_if_changed
    return unless should_reembed?

    EmbedRecordJob.perform_later(self.class.name, id)
  end

  def purge_embedding
    self.class.connection.execute(
      self.class.send(
        :sanitize_sql_array,
        [ "DELETE FROM #{self.class.embeddings_table} WHERE id = ?", id ]
      )
    )
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[Embeddable] purge failed for #{self.class.name}##{id}: #{e.message}")
  end
end
