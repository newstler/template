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
    initial_chunk_ids = doc.reload.chunks.pluck(:id).sort

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

  test "long content produces multiple chunks sized near chunk_size" do
    long = Array.new(50) { |i| "sentence #{i} here word." }.join(" ")
    doc = nil
    perform_enqueued_jobs only: RechunkRecordJob do
      doc = SearchableThing.create!(name: "Doc", description: long)
    end
    # chunk_size is 10 — expect roughly 50/10 chunks but be lenient.
    assert_operator doc.chunks.count, :>=, 4
  end
end
