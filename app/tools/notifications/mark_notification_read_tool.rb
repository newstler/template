# frozen_string_literal: true

module Notifications
  class MarkNotificationReadTool < ApplicationTool
    description "Mark a single notification as read"

    annotations(
      title: "Mark Notification as Read",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:id).filled(:string).description("The notification ID")
    end

    def call(id:)
      require_user!

      notification = current_user.notifications.find_by(id: id)
      return error_response("Notification not found", code: "not_found") unless notification

      notification.mark_as_read!
      success_response(
        { id: notification.id, read_at: format_timestamp(notification.read_at) },
        message: "Marked as read"
      )
    end
  end
end
