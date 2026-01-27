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
    end

    def call(name: nil)
      require_authentication!

      updates = {}
      updates[:name] = name if name.present?

      if updates.empty?
        return error_response("No updates provided", code: "no_updates")
      end

      current_user.update!(updates)

      success_response(
        {
          id: current_user.id,
          email: current_user.email,
          name: current_user.name,
          updated_at: format_timestamp(current_user.updated_at)
        },
        message: "Profile updated successfully"
      )
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.message, code: "validation_error")
    end
  end
end
