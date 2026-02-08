require "test_helper"

class ProviderCredentialTest < ActiveSupport::TestCase
  test "provider_settings discovers providers from RubyLLM::Configuration" do
    settings = ProviderCredential.provider_settings

    assert settings.key?("openai")
    assert settings.key?("anthropic")
    assert_includes settings["openai"], "api_key"
  end

  test "configured? returns true when api_key present" do
    assert ProviderCredential.configured?("openai")
    assert ProviderCredential.configured?("anthropic")
  end

  test "configured? returns false when api_key blank" do
    assert_not ProviderCredential.configured?("gemini")
  end

  test "set creates a new credential" do
    assert_difference "ProviderCredential.count" do
      ProviderCredential.set("gemini", "api_key", "test-key")
    end

    assert_equal "test-key", ProviderCredential.get("gemini", "api_key")
  end

  test "set updates existing credential" do
    assert_no_difference "ProviderCredential.count" do
      ProviderCredential.set("openai", "api_key", "new-key")
    end

    assert_equal "new-key", ProviderCredential.get("openai", "api_key")
  end

  test "set with blank value destroys credential" do
    assert_difference "ProviderCredential.count", -1 do
      ProviderCredential.set("openai", "api_key", "")
    end

    assert_nil ProviderCredential.get("openai", "api_key")
  end

  test "provider and key must be unique together" do
    duplicate = ProviderCredential.new(
      provider: "openai",
      key: "api_key",
      value: "duplicate"
    )

    assert_not duplicate.valid?
  end

  test "secret? detects secret fields" do
    cred = ProviderCredential.new(provider: "openai", key: "api_key")
    assert cred.secret?

    cred = ProviderCredential.new(provider: "bedrock", key: "secret_key")
    assert cred.secret?

    cred = ProviderCredential.new(provider: "openai", key: "api_base")
    assert_not cred.secret?

    cred = ProviderCredential.new(provider: "bedrock", key: "region")
    assert_not cred.secret?
  end
end
