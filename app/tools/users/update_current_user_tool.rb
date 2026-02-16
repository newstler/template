# frozen_string_literal: true

module Users
  class UpdateCurrentUserTool < ApplicationTool
    description "Update the current user's profile"

    annotations(
      title: "Update Profile",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      optional(:name).filled(:string).description("The user's display name")
      optional(:locale).filled(:string).description('Language code (e.g. "en", "es") or "auto" to clear')
    end

    def call(name: nil, locale: nil)
      require_authentication!

      updates = {}
      updates[:name] = name if name.present?
      updates[:locale] = locale == "auto" ? nil : locale if locale.present?

      if updates.empty?
        return error_response("No updates provided", code: "no_updates")
      end

      current_user.update!(updates)

      success_response(
        {
          id: current_user.id,
          email: current_user.email,
          name: current_user.name,
          locale: current_user.locale,
          updated_at: format_timestamp(current_user.updated_at)
        },
        message: "Profile updated successfully"
      )
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.message, code: "validation_error")
    end
  end
end
