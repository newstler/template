# frozen_string_literal: true

module Messages
  class CreateMessageTool < ApplicationTool
    description "Send a message to a chat and get an AI response"

    annotations(
      title: "Send Message",
      read_only_hint: false,
      open_world_hint: true
    )

    arguments do
      required(:chat_id).filled(:string).description("The chat ID")
      required(:content).filled(:string).description("The message content to send")
    end

    def call(chat_id:, content:)
      require_team!

      chat = current_user.chats.where(team: current_team).find_by(id: chat_id)
      return error_response("Chat not found", code: "not_found") unless chat

      response = nil
      with_current_user do
        response = chat.ask(content)
      end

      chat.reload

      success_response(
        {
          user_message: serialize_message(chat.messages.where(role: "user").last),
          assistant_message: serialize_message(chat.messages.where(role: "assistant").last),
          chat: {
            id: chat.id,
            messages_count: chat.messages_count,
            total_cost: chat.total_cost.to_f
          }
        },
        message: "Message sent and response received"
      )
    rescue FastMcp::Tool::InvalidArgumentsError
      raise # Re-raise authentication errors
    rescue => e
      error_response("Failed to send message: #{e.message}", code: "api_error")
    end

    private

    def serialize_message(message)
      return nil unless message

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
