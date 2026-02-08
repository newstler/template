# frozen_string_literal: true

module Models
  class RefreshModelsTool < ApplicationTool
    description "Refresh the list of available models from all configured providers (admin only)"

    admin_only!

    annotations(
      title: "Refresh Models",
      read_only_hint: false,
      open_world_hint: true
    )

    arguments do
      # No arguments required
    end

    def call
      require_admin!

      # Use RubyLLM to sync models from providers
      Model.sync_from_ruby_llm!

      models = Model.enabled.order(:provider, :name)

      success_response(
        {
          models_count: models.count,
          providers: Model.configured_providers,
          models: models.map { |m| { id: m.id, name: m.name, provider: m.provider } }
        },
        message: "Models refreshed successfully"
      )
    rescue FastMcp::Tool::InvalidArgumentsError
      raise # Re-raise authentication errors
    rescue => e
      error_response("Failed to refresh models: #{e.message}", code: "refresh_error")
    end
  end
end
