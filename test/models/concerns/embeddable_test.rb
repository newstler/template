require "test_helper"

class EmbeddableTest < ActiveSupport::TestCase
  setup do
    SearchableThing.delete_all
  end

  test "embeddable_source and embeddable_model are declared on the class" do
    skip "Filled in at Task 6 when SearchableThing includes Embeddable"
  end

  test "similar_to returns records ordered by similarity" do
    skip "Requires vec0 table and stubbed RubyLLM.embed — filled in at Task 6"
  end

  test "enqueues EmbedRecordJob on save when source changes" do
    skip "Filled in at Task 6"
  end
end
