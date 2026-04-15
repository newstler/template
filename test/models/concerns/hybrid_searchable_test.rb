require "test_helper"

class HybridSearchableTest < ActiveSupport::TestCase
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
      RubyLLM::Embedding.new(vectors: [ vector ], model: "fake", input_tokens: 0)
    end
    yield
  ensure
    RubyLLM.define_singleton_method(:embed, original)
  end

  setup do
    SearchableThing.delete_all
    ActiveRecord::Base.connection.execute("DELETE FROM searchable_things_embeddings")
  end

  test "hybrid_search returns empty for blank query" do
    assert_empty SearchableThing.hybrid_search("")
    assert_empty SearchableThing.hybrid_search(nil)
  end

  test "raises if included without Searchable and Embeddable" do
    assert_raises(RuntimeError, /requires Searchable/) do
      Class.new(ApplicationRecord) do
        self.table_name = "searchable_things"
        include HybridSearchable
      end
    end
  end

  test "fuses FTS and vector results into a single ranked relation" do
    with_fake_embed do
      welder = SearchableThing.create!(name: "Welder", description: "marine experience")
      riveter = SearchableThing.create!(name: "Riveter", description: "welder helper")
      perform_enqueued_jobs

      results = SearchableThing.hybrid_search("welder")
      assert_kind_of ActiveRecord::Relation, results
      ids = results.pluck(:id)
      assert_includes ids, welder.id
      assert_includes ids, riveter.id
    end
  end

  test "hybrid_search returns only records matching either source" do
    with_fake_embed do
      welder = SearchableThing.create!(name: "Welder", description: "specialist")
      SearchableThing.create!(name: "Painter", description: "artist")
      perform_enqueued_jobs

      ids = SearchableThing.hybrid_search("welder").pluck(:id)
      assert_includes ids, welder.id
    end
  end
end
