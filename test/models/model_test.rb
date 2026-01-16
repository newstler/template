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
end
