class ProviderCredential < ApplicationRecord
  CREDENTIAL_SUFFIXES = %w[api_key api_base secret_key region session_token project_id location organization_id].freeze

  validates :provider, presence: true
  validates :key, presence: true, uniqueness: { scope: :provider }

  after_save :reconfigure!
  after_destroy :reconfigure!

  def self.provider_settings
    config_methods = RubyLLM::Configuration.instance_methods(false)
      .map(&:to_s)
      .reject { |m| m.end_with?("=") }

    providers = {}
    config_methods.each do |method|
      CREDENTIAL_SUFFIXES.each do |suffix|
        next unless method.end_with?("_#{suffix}")
        provider = method.delete_suffix("_#{suffix}")
        (providers[provider] ||= []) << suffix
        break
      end
    end

    providers.sort.to_h
  end

  def self.configured?(provider)
    where(provider: provider, key: "api_key").where.not(value: [ nil, "" ]).exists?
  end

  def self.configure_ruby_llm!
    RubyLLM.configure do |config|
      all.each do |cred|
        attr = "#{cred.provider}_#{cred.key}"
        config.public_send(:"#{attr}=", cred.value) if config.respond_to?(:"#{attr}=")
      end
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    # DB not ready yet
  end

  def self.get(provider, key)
    find_by(provider: provider, key: key)&.value
  end

  def self.set(provider, key, value)
    if value.present?
      find_or_initialize_by(provider: provider, key: key).update!(value: value)
    else
      find_by(provider: provider, key: key)&.destroy
    end
  end

  def secret?
    key.end_with?("_key", "_secret", "_token")
  end

  private

  def reconfigure!
    self.class.configure_ruby_llm!
  end
end
