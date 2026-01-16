require "test_helper"

class ModelTest < ActiveSupport::TestCase
  setup do
    @model = models(:gpt4)
  end

  test "has required attributes" do
    assert @model.model_id.present?
    assert @model.name.present?
    assert @model.provider.present?
  end

  test "has pricing information" do
    assert @model.pricing.present?
    assert @model.pricing["text_tokens"].present?
  end

  test "provider is openai or anthropic" do
    assert_includes %w[openai anthropic], @model.provider
  end

  test "configured_providers returns providers with API keys" do
    providers = Model.configured_providers
    assert_kind_of Array, providers
    # Should only include providers from PREFERRED_PROVIDERS that have credentials
    providers.each do |provider|
      assert_includes Model::PREFERRED_PROVIDERS, provider
    end
  end

  test "with_configured_provider scope filters by configured providers" do
    models = Model.with_configured_provider
    configured = Model.configured_providers
    models.each do |model|
      assert_includes configured, model.provider
    end
  end

  test "enabled returns models from configured providers" do
    enabled = Model.enabled
    configured = Model.configured_providers
    enabled.each do |model|
      assert_includes configured, model.provider
    end
  end

  test "enabled returns unique models by name" do
    enabled = Model.enabled
    names = enabled.map(&:name)
    assert_equal names.uniq.size, names.size
  end

  test "enabled returns models sorted by name" do
    enabled = Model.enabled
    names = enabled.map(&:name)
    assert_equal names.sort, names
  end
end
