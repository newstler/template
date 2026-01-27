# frozen_string_literal: true

module Models
  class ShowModelTool < ApplicationTool
    description "Get detailed information about a specific model"

    annotations(
      title: "Show Model",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      required(:model_id).filled(:string).description("The model ID (ULID) or model_id string (e.g., 'gpt-4')")
    end

    def call(model_id:)
      model = Model.find_by(id: model_id) || Model.find_by(model_id: model_id)
      return error_response("Model not found", code: "not_found") unless model

      success_response(serialize_model(model))
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
        knowledge_cutoff: model.knowledge_cutoff&.to_s,
        capabilities: model.capabilities,
        modalities: model.modalities,
        pricing: model.pricing,
        metadata: model.metadata,
        chats_count: model.chats_count,
        total_cost: model.total_cost.to_f,
        created_at: format_timestamp(model.created_at),
        updated_at: format_timestamp(model.updated_at)
      }
    end
  end
end
