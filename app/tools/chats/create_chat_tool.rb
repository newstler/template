# frozen_string_literal: true

module Chats
  class CreateChatTool < ApplicationTool
    description "Create a new chat conversation"

    annotations(
      title: "Create Chat",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:model_id).filled(:string).description("The ID of the model to use for this chat")
      optional(:initial_message).filled(:string).description("Optional initial message to send")
    end

    def call(model_id:, initial_message: nil)
      require_team!

      model = Model.enabled.find_by(id: model_id)
      return error_response("Model not found or not enabled", code: "invalid_model") unless model

      chat = nil
      with_current_user do
        chat = current_user.chats.create!(model: model, team: current_team)

        if initial_message.present?
          chat.ask(initial_message)
        end
      end

      success_response(
        {
          id: chat.id,
          model_id: chat.model_id,
          model_name: chat.model&.name,
          messages_count: chat.messages_count,
          created_at: format_timestamp(chat.created_at)
        },
        message: "Chat created successfully"
      )
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.message, code: "validation_error")
    end
  end
end
