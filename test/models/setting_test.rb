require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "instance returns singleton row" do
    setting = Setting.instance
    assert_equal setting, Setting.instance
  end

  test "get returns attribute value" do
    assert_equal "sk_test_stripe_1234", Setting.get(:stripe_secret_key)
  end

  test "get returns nil for blank attributes" do
    setting = Setting.instance
    setting.update!(smtp_address: nil)
    assert_nil Setting.get(:smtp_address)
  end

  test "provider_configured? delegates to ProviderCredential" do
    assert Setting.provider_configured?(:openai)
    assert Setting.provider_configured?(:anthropic)
    assert_not Setting.provider_configured?(:gemini)
  end

  test "reconfigure! sets RubyLLM keys from provider credentials" do
    Setting.reconfigure!
    assert_equal "sk-test-openai-key-1234", RubyLLM.config.openai_api_key
    assert_equal "sk-ant-test-key-5678", RubyLLM.config.anthropic_api_key
  end

  test "reconfigure! sets Stripe key" do
    Setting.reconfigure!
    assert_equal "sk_test_stripe_1234", Stripe.api_key
  end
end
