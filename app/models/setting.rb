class Setting < ApplicationRecord
  ALLOWED_KEYS = %i[
    currencylayer_api_key
    default_country_code
    default_currency
    default_model
    litestream_replica_access_key litestream_replica_bucket litestream_replica_key_id
    mail_from
    moderation_model
    public_chats
    smtp_address smtp_password smtp_username
    stripe_publishable_key stripe_secret_key stripe_webhook_secret
    translation_model
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

  def self.default_model
    get(:default_model).presence
  end

  def self.translation_model
    get(:translation_model).presence
  end

  def self.moderation_model
    get(:moderation_model).presence
  end

  def self.default_currency
    get(:default_currency).presence || "USD"
  end

  def self.default_country_code
    get(:default_country_code).presence
  end

  def self.chats_enabled?
    default_model.present? && get(:public_chats) != false && Model.configured_providers.any?
  end

  def self.reconfigure!
    instance.reconfigure!
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    # DB not ready yet — skip
  end

  def reconfigure!
    ProviderCredential.configure_ruby_llm!
    configure_default_model!
    configure_stripe!
    configure_smtp!
    configure_litestream!
  end

  private

  def configure_default_model!
    model_name = has_attribute?(:default_model) ? read_attribute(:default_model) : nil
    return unless model_name.present?

    RubyLLM.configure do |config|
      config.default_model = model_name
    end
  rescue NameError, NoMethodError
    # Column or RubyLLM config may not be available during initialization
  end

  def configure_stripe!
    Stripe.api_key = stripe_secret_key
  end

  def configure_smtp!
    ActionMailer::Base.default_options = { from: mail_from } if has_attribute?(:mail_from) && mail_from.present?

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
