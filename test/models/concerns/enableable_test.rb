require "test_helper"

class EnableableTest < ActiveSupport::TestCase
  test "enabled lists only models whose provider has credentials" do
    ProviderCredential.where(provider: "anthropic").delete_all
    assert_equal %w[openai], RubyLLM::ActiveRecord::Model.enabled.distinct.pluck(:provider)
  end

  test "enabled excludes unlisted models" do
    ruby_llm_models(:gpt4).update!(unlisted_at: Time.current)
    assert_not_includes RubyLLM::ActiveRecord::Model.enabled, ruby_llm_models(:gpt4)
  end

  test "embedding returns models that output embeddings" do
    assert_equal [ ruby_llm_models(:embedding_small) ], RubyLLM::ActiveRecord::Model.embedding.to_a
  end
end
