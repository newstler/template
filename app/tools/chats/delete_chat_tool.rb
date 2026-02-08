# frozen_string_literal: true

module Chats
  class DeleteChatTool < ApplicationTool
    description "Delete a chat and all its messages"

    annotations(
      title: "Delete Chat",
      read_only_hint: false,
      destructive_hint: true,
      open_world_hint: false
    )

    arguments do
      required(:id).filled(:string).description("The chat ID to delete")
    end

    def call(id:)
      require_user!

      chat = current_user.chats.where(team: current_team).find_by(id: id)
      return error_response("Chat not found", code: "not_found") unless chat

      with_current_user do
        chat.destroy!
      end

      success_response(
        { id: id },
        message: "Chat deleted successfully"
      )
    end
  end
end
