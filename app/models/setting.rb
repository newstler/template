class Setting < ApplicationRecord
  ALLOWED_KEYS = %i[
    litestream_replica_access_key litestream_replica_bucket litestream_replica_key_id
    public_chats
    smtp_address smtp_password smtp_username
    stripe_publishable_key stripe_secret_key stripe_webhook_secret
    trial_days
  ].freeze

  after_save :reconfigure!

  def self.instance
    first || create!
  end

  def self.get(key)
    raise ArgumentError, "Unknown setting: #{key}" unless ALLOWED_KEYS.include?(key.to_sym)
    instance.public_send(key)
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    nil
  end

  def self.provider_configured?(provider)
    ProviderCredential.configured?(provider)
  end

  def self.chats_enabled?
    get(:public_chats) != false && Model.configured_providers.any?
  end

  def self.reconfigure!
    instance.reconfigure!
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    # DB not ready yet — skip
  end

  def reconfigure!
    ProviderCredential.configure_ruby_llm!
    configure_stripe!
    configure_smtp!
    configure_litestream!
  end

  private

  def configure_stripe!
    Stripe.api_key = stripe_secret_key
  end

  def configure_smtp!
    return unless Rails.env.production?
    return if smtp_address.blank?

    ActionMailer::Base.smtp_settings = {
      address: smtp_address,
      user_name: smtp_username,
      password: smtp_password,
      port: 587,
      authentication: :plain
    }
  end

  def configure_litestream!
    return unless Rails.application.config.respond_to?(:litestream)

    Rails.application.config.litestream.replica_bucket = litestream_replica_bucket
    Rails.application.config.litestream.replica_key_id = litestream_replica_key_id
    Rails.application.config.litestream.replica_access_key = litestream_replica_access_key
  end
end
