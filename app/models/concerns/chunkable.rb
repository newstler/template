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
# Rechunking runs in an +after_save_commit+ when the source digest
# changes. Move to a background job for very large documents.
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
    after_save_commit :rechunk_if_source_changed
  end

  def current_chunk_source
    proc = self.class.chunk_source_proc
    return "" unless proc

    proc.call(self).to_s
  end

  def rechunk_if_source_changed
    source = current_chunk_source
    return if source.blank?

    digest = Digest::SHA256.hexdigest(source)
    return if chunks_source_digest == digest

    rechunk(source)
  end

  def rechunk(source = current_chunk_source)
    chunks.destroy_all
    return if source.blank?

    size = self.class.chunk_size
    overlap = self.class.chunk_overlap

    new_chunks = build_chunks(source, size: size, overlap: overlap)
    new_chunks.each_with_index do |content, position|
      chunks.create!(position: position, content: content)
    end
  end

  private

  def chunks_source_digest
    return nil if chunks.empty?

    Digest::SHA256.hexdigest(chunks.ordered.pluck(:content).join(" "))
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
