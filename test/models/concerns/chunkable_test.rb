require "test_helper"

class ChunkableTest < ActiveSupport::TestCase
  setup do
    SearchableThing.delete_all
    Chunk.delete_all
  end

  test "chunks a document on create when source is non-blank" do
    doc = SearchableThing.create!(
      name: "Doc",
      description: "One two three four five. Six seven eight nine ten. Eleven twelve thirteen fourteen fifteen. Sixteen seventeen eighteen nineteen twenty."
    )
    assert doc.chunks.any?, "expected at least one chunk"
  end

  test "does not rechunk when the source is unchanged" do
    doc = SearchableThing.create!(name: "Doc", description: "Alpha beta gamma. Delta epsilon zeta.")
    initial_chunk_ids = doc.chunks.pluck(:id).sort

    doc.update!(updated_at: 1.minute.from_now)
    assert_equal initial_chunk_ids, doc.reload.chunks.pluck(:id).sort
  end

  test "rechunks when the source changes" do
    doc = SearchableThing.create!(name: "Doc", description: "Alpha beta. Gamma delta.")
    original = doc.chunks.pluck(:content)

    doc.update!(description: "One two three four five six seven eight nine ten. Eleven twelve thirteen fourteen.")
    updated = doc.reload.chunks.pluck(:content)

    assert_not_equal original, updated
  end

  test "chunks table is polymorphic" do
    doc = SearchableThing.create!(name: "Doc", description: "hello. world.")
    chunk = doc.chunks.first
    assert_equal "SearchableThing", chunk.chunkable_type
    assert_equal doc.id, chunk.chunkable_id
  end

  test "destroying a chunkable deletes its chunks" do
    doc = SearchableThing.create!(name: "Doc", description: "hello. world.")
    chunk_ids = doc.chunks.pluck(:id)
    assert_not_empty chunk_ids

    doc.destroy
    assert_equal 0, Chunk.where(id: chunk_ids).count
  end

  test "respects chunk_size when splitting long content" do
    long = Array.new(50) { |i| "sentence #{i} here word." }.join(" ")
    doc = SearchableThing.create!(name: "Doc", description: long)
    assert doc.chunks.count > 1
  end
end
