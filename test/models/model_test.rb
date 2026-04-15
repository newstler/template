require "test_helper"

class ModelTest < ActiveSupport::TestCase
  test "configured_providers only returns providers that pass provider_configured?" do
    providers = Model.configured_providers
    assert_kind_of Array, providers
    providers.each { |p| assert Setting.provider_configured?(p) }
  end

  test "enabled scope matches configured providers" do
    configured = Model.configured_providers
    enabled_models = Model.enabled

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
