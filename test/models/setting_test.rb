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

  test "stripe_configured? is true when secret key is set" do
    Setting.instance.update!(stripe_secret_key: "sk_test_123")
    assert Setting.stripe_configured?
  end

  test "default_language returns stored value" do
    Setting.instance.update!(default_language: "es")
    assert_equal "es", Setting.default_language
  end

  test "default_language falls back to en when blank" do
    Setting.instance.update!(default_language: nil)
    assert_equal "en", Setting.default_language

    Setting.instance.update!(default_language: "")
    assert_equal "en", Setting.default_language
  end

  test "stripe_configured? is false when secret key is blank" do
    Setting.instance.update!(stripe_secret_key: nil)
    assert_not Setting.stripe_configured?

    Setting.instance.update!(stripe_secret_key: "")
    assert_not Setting.stripe_configured?
  end
end
