class Model < ApplicationRecord
  acts_as_model chats_foreign_key: :model_id
  has_many :chats, foreign_key: :model_id

  # Recalculate total cost from all chats
  def recalculate_total_cost!
    update_column(:total_cost, chats.sum(:total_cost))
  end

  # Format total cost for display
  def formatted_total_cost
    cost = read_attribute(:total_cost) || 0
    return nil if cost.zero?

    if cost < 0.0001
      "<$0.0001"
    else
      "$#{'%.4f' % cost}"
    end
  end

  # Preferred providers in priority order for deduplication
  PREFERRED_PROVIDERS = %w[anthropic openai google gemini mistral deepseek perplexity vertexai bedrock openrouter].freeze

  # Returns providers that have API keys configured in credentials
  def self.configured_providers
    PREFERRED_PROVIDERS.select do |provider|
      Rails.application.credentials.dig(provider.to_sym, :api_key).present?
    end
  end

  # Scope to filter by configured providers
  scope :with_configured_provider, -> { where(provider: configured_providers) }

  # Returns one model per unique name, preferring primary providers
  scope :unique_by_name, -> {
    # Use a subquery to get the preferred model_id for each name
    preferred_ids = select("MIN(id) as id")
      .group(:name)
      .order(Arel.sql("CASE provider " +
        PREFERRED_PROVIDERS.each_with_index.map { |p, i| "WHEN '#{p}' THEN #{i}" }.join(" ") +
        " ELSE 999 END"))

    where(id: preferred_ids)
  }

  # Returns enabled models (configured providers, deduplicated by name)
  def self.enabled
    models_by_name = with_configured_provider.group_by(&:name)
    models_by_name.map do |_name, models|
      models.min_by { |m| PREFERRED_PROVIDERS.index(m.provider) || 999 }
    end.sort_by(&:name)
  end
end
