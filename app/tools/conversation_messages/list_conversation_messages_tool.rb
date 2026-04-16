# frozen_string_literal: true

module ConversationMessages
  class ListConversationMessagesTool < ApplicationTool
    description "List messages in a conversation"

    annotations(
      title: "List Conversation Messages",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      required(:conversation_id).filled(:string).description("Conversation ID")
      optional(:limit).filled(:integer).description("Max messages to return (default 50)")
    end

    def call(conversation_id:, limit: 50)
      require_user!

      conversation = current_team.conversations.find_by(id: conversation_id)
      return error_response("Conversation not found") unless conversation

      unless conversation.conversation_participants.exists?(user: current_user)
        return error_response("Not a participant of this conversation")
      end

      messages = conversation.conversation_messages.includes(:user).chronologically.last(limit)
      success_response(messages.map { |m| serialize_message(m) })
    end

    private

    def serialize_message(message)
      visible = message.visible_to?(current_user)
      {
        id: message.id,
        user_id: message.user_id,
        content: visible ? message.body_for(current_user) : nil,
        flagged: message.flagged_at.present?,
        hidden: !visible,
        created_at: format_timestamp(message.created_at)
      }
    end
  end
end
