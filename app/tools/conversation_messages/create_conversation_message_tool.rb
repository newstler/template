# frozen_string_literal: true

module ConversationMessages
  class CreateConversationMessageTool < ApplicationTool
    description "Post a new message to a conversation as the current user"

    annotations(
      title: "Create Conversation Message",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:conversation_id).filled(:string).description("Conversation ID")
      required(:content).filled(:string).description("Message content")
    end

    def call(conversation_id:, content:)
      with_current_user do
        conversation = current_team.conversations.find_by(id: conversation_id)
        return error_response("Conversation not found") unless conversation

        unless conversation.conversation_participants.exists?(user: current_user)
          return error_response("Not a participant of this conversation")
        end

        message = conversation.conversation_messages.create!(user: current_user, content: content)
        message.broadcast_to_other_participants
        message.mark_recipient_participants_pending

        success_response(
          {
            id: message.id,
            conversation_id: message.conversation_id,
            content: message.content,
            created_at: format_timestamp(message.created_at)
          },
          message: "Message sent"
        )
      end
    end
  end
end
