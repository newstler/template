require "test_helper"

class ChunkableTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    SearchableThing.delete_all
    Chunk.delete_all
  end

  test "enqueues RechunkRecordJob on create when source is present" do
    assert_enqueued_with(job: RechunkRecordJob) do
      SearchableThing.create!(name: "Doc", description: "hello. world.")
    end
  end

  test "chunks a document on create via the async job" do
    doc = nil
    perform_enqueued_jobs only: RechunkRecordJob do
      doc = SearchableThing.create!(
        name: "Doc",
        description: "One two three four five. Six seven eight nine ten."
      )
    end
    assert doc.chunks.any?, "expected at least one chunk"
  end

  test "does not rechunk when the source is unchanged" do
    doc = nil
    perform_enqueued_jobs only: RechunkRecordJob do
      doc = SearchableThing.create!(name: "Doc", description: "Alpha beta gamma. Delta epsilon zeta.")
    end
    doc.reload
    initial_chunk_ids = doc.chunks.pluck(:id).sort

    assert_no_enqueued_jobs only: RechunkRecordJob do
      doc.update!(updated_at: 1.minute.from_now)
    end
    assert_equal initial_chunk_ids, doc.reload.chunks.pluck(:id).sort
  end

  test "rechunks when the source changes" do
    doc = nil
    perform_enqueued_jobs only: RechunkRecordJob do
      doc = SearchableThing.create!(name: "Doc", description: "Alpha beta. Gamma delta.")
    end
    original = doc.chunks.pluck(:content).sort

    perform_enqueued_jobs only: RechunkRecordJob do
      doc.update!(description: "One two three four five six seven eight nine ten. Eleven twelve thirteen fourteen.")
    end
    updated = doc.reload.chunks.pluck(:content).sort

    assert_not_equal original, updated
  end

  test "chunks table is polymorphic" do
    doc = nil
    perform_enqueued_jobs only: RechunkRecordJob do
      doc = SearchableThing.create!(name: "Doc", description: "hello. world.")
    end
    chunk = doc.chunks.first
    assert_equal "SearchableThing", chunk.chunkable_type
    assert_equal doc.id, chunk.chunkable_id
  end

  test "destroying a chunkable deletes its chunks" do
    doc = nil
    perform_enqueued_jobs only: RechunkRecordJob do
      doc = SearchableThing.create!(name: "Doc", description: "hello. world.")
    end
    chunk_ids = doc.chunks.pluck(:id)
    assert_not_empty chunk_ids

    doc.destroy
    assert_equal 0, Chunk.where(id: chunk_ids).count
  end

  test "respects chunk_size when splitting long content" do
    long = Array.new(50) { |i| "sentence #{i} here word." }.join(" ")
    doc = nil
    perform_enqueued_jobs only: RechunkRecordJob do
      doc = SearchableThing.create!(name: "Doc", description: long)
    end
    assert doc.chunks.count > 1
  end

  test "rechunk uses bulk insert via insert_all" do
    doc = nil
    perform_enqueued_jobs only: RechunkRecordJob do
      doc = SearchableThing.create!(name: "Doc", description: "One. Two. Three. Four. Five.")
    end

    insert_all_called = false
    original = Chunk.method(:insert_all)
    Chunk.define_singleton_method(:insert_all) do |*args, **kwargs|
      insert_all_called = true
      original.call(*args, **kwargs)
    end

    begin
      doc.update!(description: "Alpha. Beta. Gamma. Delta. Epsilon.")
      perform_enqueued_jobs only: RechunkRecordJob
    ensure
      Chunk.define_singleton_method(:insert_all, original)
    end

    assert insert_all_called, "expected Chunk.insert_all to be called during rechunk"
  end
end
