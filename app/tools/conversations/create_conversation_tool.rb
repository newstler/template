# frozen_string_literal: true

module Conversations
  class CreateConversationTool < ApplicationTool
    description "Create (or find) a conversation in the current team with a set of participants"

    annotations(
      title: "Create Conversation",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      optional(:title).filled(:string).description("Conversation title")
      optional(:participant_emails).array(:string).description("Emails of additional participants; current user is added automatically")
    end

    def call(title: nil, participant_emails: [])
      with_current_user do
        emails = Array(participant_emails).map(&:to_s).map(&:downcase).uniq
        users = User.where(email: emails)
        # Only allow participants who are members of this team
        users = users.joins(:memberships).where(memberships: { team_id: current_team.id }).distinct
        participants = ([ current_user ] + users.to_a).uniq

        conversation = current_team.conversations.create!(title: title)
        participants.each do |user|
          conversation.conversation_participants.find_or_create_by!(user: user)
        end

        success_response(
          {
            id: conversation.id,
            title: conversation.title,
            participant_ids: conversation.conversation_participants.pluck(:user_id)
          },
          message: "Conversation created"
        )
      end
    end
  end
end
