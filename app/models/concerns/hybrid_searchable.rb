# HybridSearchable: fuses full-text (FTS5) and vector (vec0) results
# via Reciprocal Rank Fusion. Requires both +Searchable+ and
# +Embeddable+ to be included first.
#
# Usage:
#   class Candidate < ApplicationRecord
#     include Searchable
#     include Embeddable
#     include HybridSearchable
#   end
#
#   Candidate.hybrid_search("welder marine experience", limit: 20)
#
# Returns an ActiveRecord::Relation ordered by fused RRF score
# (higher = better). Score is computed as:
#
#   rrf(id) = sum_over_lists(1 / (k + rank_in_list(id)))
#
# with rank 1-indexed and +k+ drawn from +Setting.rrf_k+ (default 60,
# per Cormack et al., SIGIR 2009). RRF sidesteps the score
# normalization problem between bm25 and cosine similarity.
module HybridSearchable
  extend ActiveSupport::Concern

  included do
    unless include?(Searchable) && include?(Embeddable)
      raise "HybridSearchable requires Searchable and Embeddable to be included first"
    end
  end

  class_methods do
    def hybrid_search(query, limit: 20)
      return none if query.blank?

      k = Setting.rrf_k
      pool_size = limit * 3

      fts_ids = search(query).limit(pool_size).pluck(:id)
      vector_ids = similar_to(query, limit: pool_size).pluck(:id)

      return none if fts_ids.empty? && vector_ids.empty?

      scores = Hash.new(0.0)
      fts_ids.each_with_index { |id, i| scores[id] += 1.0 / (k + i + 1) }
      vector_ids.each_with_index { |id, i| scores[id] += 1.0 / (k + i + 1) }

      ordered_ids = scores.sort_by { |_, score| -score }.first(limit).map(&:first)
      where(id: ordered_ids).in_order_of(:id, ordered_ids)
    end
  end
end
