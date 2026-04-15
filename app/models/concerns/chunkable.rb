# Chunkable: splits long documents into embedding-sized pieces stored
# in the polymorphic +chunks+ table.
#
# Usage:
#   class Article < ApplicationRecord
#     include Chunkable
#     chunk_source ->(r) { r.body }
#     chunk_size 400      # words per chunk (approximate)
#     chunk_overlap 40    # words carried into the next chunk
#   end
#
# Chunks are polymorphic +Chunk+ records and include +Embeddable+, so
# each chunk has its own vec0 row. Combine with +include Embeddable+
# on the parent record if you also want a single aggregate vector.
#
# Rechunking runs via RechunkRecordJob in a background job, and chunks
# are bulk-inserted via +insert_all+.
module Chunkable
  extend ActiveSupport::Concern

  DEFAULT_CHUNK_SIZE = 400
  DEFAULT_CHUNK_OVERLAP = 40

  class_methods do
    def chunk_source(proc = nil, &block)
      @chunk_source = proc || block
    end

    def chunk_source_proc
      @chunk_source
    end

    def chunk_size(size = nil)
      @chunk_size = size if size
      @chunk_size || DEFAULT_CHUNK_SIZE
    end

    def chunk_overlap(overlap = nil)
      @chunk_overlap = overlap if overlap
      @chunk_overlap || DEFAULT_CHUNK_OVERLAP
    end
  end

  included do
    has_many :chunks, as: :chunkable, dependent: :destroy
    after_save_commit :enqueue_rechunk_if_source_changed
  end

  def current_chunk_source
    proc = self.class.chunk_source_proc
    return "" unless proc

    proc.call(self).to_s
  end

  # Hash the current source text directly. Does not touch the +chunks+
  # association — inexpensive to call on every save.
  def chunks_source_digest
    source = current_chunk_source
    return nil if source.blank?

    Digest::SHA256.hexdigest(source)
  end

  def enqueue_rechunk_if_source_changed
    return unless chunks_source_changed?
    RechunkRecordJob.perform_later(self)
  end

  def rechunk
    source = current_chunk_source
    chunks.delete_all
    return if source.blank?

    size = self.class.chunk_size
    overlap = self.class.chunk_overlap
    now = Time.current

    rows = build_chunks(source, size: size, overlap: overlap).each_with_index.map do |content, position|
      {
        chunkable_type: self.class.base_class.name,
        chunkable_id: id,
        position: position,
        content: content,
        created_at: now,
        updated_at: now
      }
    end

    Chunk.insert_all(rows) if rows.any?
    persist_chunks_source_digest
  end

  private

  def chunks_source_changed?
    digest = chunks_source_digest
    return false if digest.nil?
    return true unless has_attribute?(:chunks_source_digest)

    read_attribute(:chunks_source_digest) != digest
  end

  def persist_chunks_source_digest
    return unless has_attribute?(:chunks_source_digest)
    digest = chunks_source_digest
    update_columns(chunks_source_digest: digest) if digest
  end

  def build_chunks(source, size:, overlap:)
    sentences = source.split(/(?<=[.!?])\s+/).reject(&:blank?)
    result = []
    current = []
    current_size = 0

    sentences.each do |sentence|
      words = sentence.split(/\s+/).size

      if current_size + words > size && current.any?
        result << current.join(" ")
        carry = current.last(overlap_sentence_count(current, overlap))
        current = carry.dup
        current_size = current.sum { |s| s.split(/\s+/).size }
      end

      current << sentence
      current_size += words
    end

    result << current.join(" ") if current.any?
    result
  end

  # Returns how many trailing sentences to keep as overlap so the
  # carried word count is <= +overlap+.
  def overlap_sentence_count(sentences, overlap)
    return 0 if overlap.zero? || sentences.empty?

    kept = 0
    carried = 0
    sentences.reverse_each do |sentence|
      words = sentence.split(/\s+/).size
      break if carried + words > overlap

      kept += 1
      carried += words
    end
    kept
  end
end
