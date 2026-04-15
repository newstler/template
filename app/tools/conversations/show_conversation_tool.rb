# frozen_string_literal: true

module Conversations
  class ShowConversationTool < ApplicationTool
    description "Show a conversation's details, participants, and recent messages"

    annotations(
      title: "Show Conversation",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      required(:id).filled(:string).description("Conversation ID")
      optional(:message_limit).filled(:integer).description("Max messages to include (default 20)")
    end

    def call(id:, message_limit: 20)
      require_user!

      conversation = current_team.conversations.find_by(id: id)
      return error_response("Conversation not found") unless conversation

      unless conversation.conversation_participants.exists?(user: current_user)
        return error_response("Not a participant of this conversation")
      end

      messages = conversation.conversation_messages
        .includes(:user)
        .chronologically
        .last(message_limit)

      success_response({
        id: conversation.id,
        title: conversation.title,
        subject_type: conversation.subject_type,
        subject_id: conversation.subject_id,
        participant_ids: conversation.conversation_participants.pluck(:user_id),
        messages: messages.map { |m| serialize_message(m) }
      })
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
