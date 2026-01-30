# frozen_string_literal: true

module Messages
  class ListMessagesTool < ApplicationTool
    description "List messages in a chat with pagination support"

    annotations(
      title: "List Messages",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      required(:chat_id).filled(:string).description("The chat ID")
      optional(:limit).filled(:integer).description("Maximum number of messages to return (default: 50)")
      optional(:after_id).filled(:string).description("Return messages after this message ID (for pagination)")
    end

    def call(chat_id:, limit: 50, after_id: nil)
      require_team!

      chat = current_user.chats.where(team: current_team).find_by(id: chat_id)
      return error_response("Chat not found", code: "not_found") unless chat

      messages = chat.messages.order(:created_at)

      if after_id.present?
        after_message = messages.find_by(id: after_id)
        if after_message
          messages = messages.where("created_at > ?", after_message.created_at)
        end
      end

      messages = messages.limit(limit)

      success_response(
        messages.map { |msg| serialize_message(msg) },
        message: "Found #{messages.size} messages"
      )
    end

    private

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
