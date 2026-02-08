# frozen_string_literal: true

module Teams
  class ListTeamsTool < ApplicationTool
    description "List teams the current user belongs to"

    annotations(
      title: "List Teams",
      read_only_hint: true,
      open_world_hint: false
    )

    def call
      require_authentication!

      teams = current_user.teams.includes(:memberships)

      success_response(
        teams.map { |team| serialize_team(team) },
        message: "Found #{teams.size} teams"
      )
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
        created_at: format_timestamp(team.created_at)
      }
    end
  end
end
