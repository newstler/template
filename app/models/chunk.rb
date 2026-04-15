# Polymorphic chunk belonging to any +Chunkable+ parent. Each chunk
# embeds its own content so long documents can be retrieved by their
# most relevant chunk rather than by a single averaged vector.
class Chunk < ApplicationRecord
  include Embeddable

  belongs_to :chunkable, polymorphic: true

  embeddable_source ->(chunk) { chunk.content }
  embeddable_model  -> { Setting.embedding_model }
  embeddable_distance :cosine

  scope :ordered, -> { order(:position) }
end
