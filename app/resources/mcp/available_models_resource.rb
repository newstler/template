# frozen_string_literal: true

module Mcp
  class AvailableModelsResource < ApplicationResource
    uri "app:///models"
    resource_name "Available Models"
    description "List of all AI models available for use"
    mime_type "application/json"

    def content
      models = Model.enabled.order(:provider, :name)

      to_json({
        models_count: models.count,
        providers: Model.configured_providers,
        models: models.map { |model| serialize_model(model) }
      })
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
        pricing: model.pricing
      }
    end
  end
end
