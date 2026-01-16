class Model < ApplicationRecord
  acts_as_model chats_foreign_key: :model_id

  # Preferred providers in priority order for deduplication
  PREFERRED_PROVIDERS = %w[anthropic openai google gemini mistral deepseek perplexity vertexai bedrock openrouter].freeze

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

  # Simpler approach: select distinct names with preferred provider
  def self.for_select
    # Group by name and pick the one with the most preferred provider
    models_by_name = all.group_by(&:name)
    models_by_name.map do |name, models|
      # Sort by provider preference and pick the first
      preferred = models.min_by { |m| PREFERRED_PROVIDERS.index(m.provider) || 999 }
      preferred
    end.sort_by(&:name)
  end
end
