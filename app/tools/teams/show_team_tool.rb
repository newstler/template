# frozen_string_literal: true

module Teams
  class ShowTeamTool < ApplicationTool
    description "Get details of a specific team"

    annotations(
      title: "Show Team",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      required(:slug).filled(:string).description("The team slug")
    end

    def call(slug:)
      require_authentication!

      team = current_user.teams.find_by(slug: slug)
      return error_response("Team not found", code: "not_found") unless team

      success_response(serialize_team(team))
    end

    private

    def serialize_team(team)
      membership = current_user.membership_for(team)
      {
        id: team.id,
        name: team.name,
        slug: team.slug,
        role: membership&.role,
        member_count: team.memberships.count,
        total_chat_cost: team.total_chat_cost.to_f,
        members: team.memberships.includes(:user, :invited_by).map { |m| serialize_membership(m) },
        created_at: format_timestamp(team.created_at)
      }
    end

    def serialize_membership(membership)
      {
        user_id: membership.user_id,
        user_name: membership.user.name,
        user_email: membership.user.email,
        role: membership.role,
        invited_by: membership.invited_by&.name,
        joined_at: format_timestamp(membership.created_at)
      }
    end
  end
end
