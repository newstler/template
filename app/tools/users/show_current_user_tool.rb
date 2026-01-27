# frozen_string_literal: true

module Users
  class ShowCurrentUserTool < ApplicationTool
    description "Get information about the currently authenticated user"

    annotations(
      title: "Show Current User",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      # No arguments required
    end

    def call
      require_authentication!

      success_response(serialize_user(current_user))
    end

    private

    def serialize_user(user)
      {
        id: user.id,
        email: user.email,
        name: user.name,
        chats_count: user.chats.count,
        total_cost: user.total_cost.to_f,
        created_at: format_timestamp(user.created_at),
        updated_at: format_timestamp(user.updated_at)
      }
    end
  end
end
