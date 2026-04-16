# frozen_string_literal: true

module Conversations
  class ListConversationsTool < ApplicationTool
    description "List conversations the current user participates in (scoped to team)"

    annotations(
      title: "List Conversations",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      optional(:limit).filled(:integer).description("Max conversations to return")
    end

    def call(limit: 20)
      require_user!

      conversations = current_team.conversations
        .joins(:conversation_participants)
        .where(conversation_participants: { user_id: current_user.id })
        .includes(:conversation_participants)
        .chronologically
        .limit(limit)

      success_response(conversations.map { |c| serialize_conversation(c) })
    end

    private

    def serialize_conversation(conversation)
      {
        id: conversation.id,
        title: conversation.title,
        subject_type: conversation.subject_type,
        subject_id: conversation.subject_id,
        participant_ids: conversation.conversation_participants.map(&:user_id),
        updated_at: format_timestamp(conversation.updated_at)
      }
    end
  end
end
