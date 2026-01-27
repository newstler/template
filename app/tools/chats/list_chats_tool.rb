# frozen_string_literal: true

module Chats
  class ListChatsTool < ApplicationTool
    description "List all chats for the authenticated user"

    annotations(
      title: "List Chats",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      optional(:limit).filled(:integer).description("Maximum number of chats to return (default: 20)")
      optional(:offset).filled(:integer).description("Number of chats to skip (default: 0)")
      optional(:order).filled(:string).description("Sort order: 'recent' (default) or 'oldest'")
    end

    def call(limit: 20, offset: 0, order: "recent")
      require_authentication!

      chats = current_user.chats
      chats = order == "oldest" ? chats.chronologically : chats.recent
      chats = chats.includes(:model).offset(offset).limit(limit)

      success_response(
        chats.map { |chat| serialize_chat(chat) },
        message: "Found #{chats.size} chats"
      )
    end

    private

    def serialize_chat(chat)
      {
        id: chat.id,
        model_id: chat.model_id,
        model_name: chat.model&.name,
        messages_count: chat.messages_count,
        total_cost: chat.total_cost.to_f,
        created_at: format_timestamp(chat.created_at),
        updated_at: format_timestamp(chat.updated_at)
      }
    end
  end
end
