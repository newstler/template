require "test_helper"

class EmbeddableTest < ActiveSupport::TestCase
  # Deterministic stub embedding — hashes the first word of the input
  # to pick a unique dimension, so strings sharing their first word
  # land on the same vec0 coordinate (distance 0).
  FAKE_DIMENSIONS = 1536

  def fake_embed(text)
    token = text.to_s.downcase.split(/\W+/).first.to_s
    seed = token.each_char.sum(&:ord)
    Array.new(FAKE_DIMENSIONS, 0.0).tap { |v| v[seed % FAKE_DIMENSIONS] = 1.0 }
  end

  def with_fake_embed
    original = RubyLLM.method(:embed)
    test = self
    RubyLLM.define_singleton_method(:embed) do |text, **_opts|
      vector = test.fake_embed(text)
      RubyLLM::Embedding.new(vectors: vector, model: "fake", input_tokens: 0)
    end
    yield
  ensure
    RubyLLM.define_singleton_method(:embed, original)
  end

  setup do
    SearchableThing.delete_all
    ActiveRecord::Base.connection.execute("DELETE FROM searchable_things_embeddings")
  end

  test "embeddings_table name is derived from the model" do
    assert_equal "searchable_things_embeddings", SearchableThing.embeddings_table
  end

  test "does not enqueue EmbedRecordJob when source is blank" do
    assert_no_enqueued_jobs only: EmbedRecordJob do
      SearchableThing.create!(name: "")
    end
  end

  test "enqueues EmbedRecordJob on create with a non-blank source" do
    assert_enqueued_with(job: EmbedRecordJob) do
      SearchableThing.create!(name: "Welder", description: "Russian speaker")
    end
  end

  test "does not re-enqueue when source hash is unchanged" do
    with_fake_embed do
      thing = SearchableThing.create!(name: "Welder", description: "Russian speaker")
      perform_enqueued_jobs

      assert_no_enqueued_jobs only: EmbedRecordJob do
        # Touching an attribute that isn't part of the source leaves
        # the digest unchanged so the after_commit callback must skip.
        thing.update!(updated_at: 1.minute.from_now)
      end
    end
  end

  test "re-enqueues when the source string changes" do
    with_fake_embed do
      thing = SearchableThing.create!(name: "Welder")
      perform_enqueued_jobs

      assert_enqueued_with(job: EmbedRecordJob) do
        thing.update!(name: "Welder Senior")
      end
    end
  end

  test "writes vector to vec0 table and purges on destroy" do
    with_fake_embed do
      thing = SearchableThing.create!(name: "Diver", description: "Underwater")
      perform_enqueued_jobs

      count = ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM searchable_things_embeddings WHERE id = #{ActiveRecord::Base.connection.quote(thing.id)}"
      )
      assert_equal 1, count

      thing.destroy
      count_after = ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM searchable_things_embeddings WHERE id = #{ActiveRecord::Base.connection.quote(thing.id)}"
      )
      assert_equal 0, count_after
    end
  end

  test "similar_to returns records ordered by vec0 distance" do
    with_fake_embed do
      welder = SearchableThing.create!(name: "Welder", description: "marine experience")
      diver = SearchableThing.create!(name: "Diver", description: "scuba certified")
      perform_enqueued_jobs

      # Query string shares first word with welder so its seed maps
      # to the same dimension => distance 0 ranks it first.
      results = SearchableThing.similar_to("Welder")

      assert_equal [ welder.id, diver.id ], results.pluck(:id)
      assert_equal 0.0, results.first.similarity_distance
    end
  end

  test "similar_to returns an ActiveRecord relation composable with where" do
    with_fake_embed do
      SearchableThing.create!(name: "Welder", description: "marine")
      SearchableThing.create!(name: "Welder", description: "industrial")
      perform_enqueued_jobs

      relation = SearchableThing.similar_to("Welder").where("description LIKE ?", "%marine%")
      assert_kind_of ActiveRecord::Relation, relation
      assert_equal 1, relation.count
    end
  end

  test "similar_to returns none for blank query" do
    assert_empty SearchableThing.similar_to("")
    assert_empty SearchableThing.similar_to(nil)
  end

  test "similar_to filter_by pre-filters on a metadata column" do
    with_fake_embed do
      marine = SearchableThing.create!(name: "Welder", description: "marine experience", tags: "marine")
      _industrial = SearchableThing.create!(name: "Welder", description: "industrial site", tags: "industrial")
      perform_enqueued_jobs

      results = SearchableThing.similar_to("Welder", filter_by: { tags: "marine" })

      assert_equal [ marine.id ], results.pluck(:id)
    end
  end
end
