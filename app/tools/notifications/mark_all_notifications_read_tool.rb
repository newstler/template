# frozen_string_literal: true

module Notifications
  class MarkAllNotificationsReadTool < ApplicationTool
    description "Mark all of the authenticated user's unread notifications as read"

    annotations(
      title: "Mark All Notifications as Read",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
    end

    def call
      require_user!

      unread = current_user.visible_notifications.unread
      count = unread.count
      unread.mark_as_read

      success_response(
        { marked_read_count: count },
        message: "Marked #{count} notifications as read"
      )
    end
  end
end
