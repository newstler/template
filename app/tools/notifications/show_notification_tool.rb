# frozen_string_literal: true

module Notifications
  class ShowNotificationTool < ApplicationTool
    description "Get details of a specific notification"

    annotations(
      title: "Show Notification",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      required(:id).filled(:string).description("The notification ID")
    end

    def call(id:)
      require_user!

      notification = current_user.notifications.includes(:event).find_by(id: id)
      return error_response("Notification not found", code: "not_found") unless notification

      success_response(serialize_notification(notification))
    end

    private

    def serialize_notification(notification)
      {
        id: notification.id,
        type: notification.event.type,
        message: safe_message(notification),
        url: safe_url(notification),
        params: notification.event.params,
        read_at: format_timestamp(notification.read_at),
        seen_at: format_timestamp(notification.seen_at),
        created_at: format_timestamp(notification.created_at)
      }
    end

    def safe_message(notification)
      notification.message
    rescue StandardError
      nil
    end

    def safe_url(notification)
      notification.url
    rescue StandardError
      nil
    end
  end
end
