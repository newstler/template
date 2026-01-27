# frozen_string_literal: true

module Chats
  class ShowChatTool < ApplicationTool
    description "Get details of a specific chat, optionally including messages"

    annotations(
      title: "Show Chat",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      required(:id).filled(:string).description("The chat ID")
      optional(:include_messages).filled(:bool).description("Include messages in response (default: true)")
    end

    def call(id:, include_messages: true)
      require_authentication!

      chat = current_user.chats.find_by(id: id)
      return error_response("Chat not found", code: "not_found") unless chat

      success_response(serialize_chat(chat, include_messages: include_messages))
    end

    private

    def serialize_chat(chat, include_messages:)
      data = {
        id: chat.id,
        model_id: chat.model_id,
        model_name: chat.model&.name,
        messages_count: chat.messages_count,
        total_cost: chat.total_cost.to_f,
        created_at: format_timestamp(chat.created_at),
        updated_at: format_timestamp(chat.updated_at)
      }

      if include_messages
        data[:messages] = chat.messages.order(:created_at).map { |msg| serialize_message(msg) }
      end

      data
    end

    def serialize_message(message)
      {
        id: message.id,
        role: message.role,
        content: message.content,
        model_id: message.model_id,
        input_tokens: message.input_tokens,
        output_tokens: message.output_tokens,
        cost: message.cost&.to_f,
        created_at: format_timestamp(message.created_at)
      }
    end
  end
end
