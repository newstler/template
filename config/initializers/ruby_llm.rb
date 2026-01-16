begin
  RubyLLM.configure do |config|
    config.openai_api_key = Rails.application.credentials.dig(:openai, :api_key)
    config.default_model = "gpt-4.1-nano"

    config.anthropic_api_key = Rails.application.credentials.dig(:anthropic, :api_key)

    # Use the new association-based acts_as API (recommended)
    config.use_new_acts_as = true
  end
rescue ActiveSupport::MessageEncryptor::InvalidMessage
  # Credentials not yet configured - skip RubyLLM configuration
  # This is expected during initial setup (bin/configure)
  Rails.logger.debug "RubyLLM credentials not configured yet" if Rails.logger
end
