# frozen_string_literal: true

module Models
  class ListModelsTool < ApplicationTool
    description "List available AI models"

    annotations(
      title: "List Models",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      optional(:provider).filled(:string).description("Filter by provider (e.g., 'openai', 'anthropic')")
      optional(:enabled_only).filled(:bool).description("Only return models with configured API keys (default: true)")
    end

    def call(provider: nil, enabled_only: true)
      models = enabled_only ? Model.enabled : Model.all
      models = models.where(provider: provider) if provider.present?
      models = models.order(:provider, :name)

      success_response(
        models.map { |model| serialize_model(model) },
        message: "Found #{models.size} models"
      )
    end

    private

    def serialize_model(model)
      {
        id: model.id,
        model_id: model.model_id,
        name: model.name,
        provider: model.provider,
        family: model.family,
        context_window: model.context_window,
        max_output_tokens: model.max_output_tokens,
        capabilities: model.capabilities,
        pricing: model.pricing,
        chats_count: model.chats_count,
        total_cost: model.total_cost.to_f
      }
    end
  end
end
