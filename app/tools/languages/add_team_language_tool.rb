# frozen_string_literal: true

module Languages
  class AddTeamLanguageTool < ApplicationTool
    description "Add a language to the team for automatic content translation"

    annotations(
      title: "Add Team Language",
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

      language = Language.enabled.find_by(code: language_code)
      return error_response("Language not found or not enabled: #{language_code}") unless language

      current_team.enable_language!(language)
      BackfillTranslationsJob.perform_later(current_team.id, language.code)

      success_response(
        { code: language.code, name: language.name, native_name: language.native_name },
        message: "#{language.name} added. Existing content is being translated."
      )
    end
  end
end
