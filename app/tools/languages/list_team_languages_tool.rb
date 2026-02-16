# frozen_string_literal: true

module Languages
  class ListTeamLanguagesTool < ApplicationTool
    description "List active languages for the current team"

    annotations(
      title: "List Team Languages",
      read_only_hint: true,
      open_world_hint: false
    )

    def call
      require_user!

      languages = current_team.team_languages.active.includes(:language).map(&:language)

      success_response(languages.map { |l|
        {
          id: l.id,
          code: l.code,
          name: l.name,
          native_name: l.native_name
        }
      })
    end
  end
end
