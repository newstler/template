# frozen_string_literal: true

module Chats
  class UpdateChatTool < ApplicationTool
    description "Update a chat's model"

    annotations(
      title: "Update Chat",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:id).filled(:string).description("The chat ID")
      required(:model_id).filled(:string).description("The new model ID to use")
    end

    def call(id:, model_id:)
      require_user!

      chat = current_user.chats.where(team: current_team).find_by(id: id)
      return error_response("Chat not found", code: "not_found") unless chat

      model = Model.enabled.find_by(id: model_id)
      return error_response("Model not found or not enabled", code: "invalid_model") unless model

      with_current_user do
        chat.with_model(model.model_id)
      end

      success_response(
        {
          id: chat.id,
          model_id: chat.model_id,
          model_name: chat.model&.name,
          updated_at: format_timestamp(chat.updated_at)
        },
        message: "Chat model updated successfully"
      )
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.message, code: "validation_error")
    end
  end
end
