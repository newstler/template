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
    providers.each do |provider|
      assert Rails.application.credentials.dig(provider.to_sym, :api_key).present?
    end
  end

  test "enabled scope filters by configured providers" do
    configured = Model.configured_providers
    enabled_models = Model.enabled

    # Either no configured providers means no enabled models,
    # or all enabled models have configured providers
    if configured.empty?
      assert_empty enabled_models
    else
      assert enabled_models.any?, "Expected some enabled models when providers are configured"
      enabled_models.each do |model|
        assert_includes configured, model.provider
      end
    end
  end
end
