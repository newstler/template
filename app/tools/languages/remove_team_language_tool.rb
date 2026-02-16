# frozen_string_literal: true

module Languages
  class RemoveTeamLanguageTool < ApplicationTool
    description "Remove a language from the team (soft-disable, translations preserved)"

    annotations(
      title: "Remove Team Language",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:language_code).filled(:string).description("ISO 639-1 language code (e.g., 'es', 'fr')")
    end

    def call(language_code:)
      require_user!

      membership = current_user.membership_for(current_team)
      unless membership&.admin?
        return error_response("Admin access required")
      end

      language = Language.find_by(code: language_code)
      return error_response("Language not found: #{language_code}") unless language

      if current_team.team_languages.active.count <= 1
        return error_response("At least one language is required")
      end

      current_team.disable_language!(language)

      success_response(
        { code: language.code, name: language.name },
        message: "#{language.name} removed from team languages"
      )
    end
  end
end
