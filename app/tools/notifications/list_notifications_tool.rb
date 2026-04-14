# frozen_string_literal: true

module Notifications
  class ListNotificationsTool < ApplicationTool
    description "List the authenticated user's notifications (newest first)"

    annotations(
      title: "List Notifications",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      optional(:limit).filled(:integer).description("Max notifications to return (default: 20)")
      optional(:unread_only).filled(:bool).description("Only return unread notifications (default: false)")
    end

    def call(limit: 20, unread_only: false)
      require_user!

      scope = current_user.notifications.includes(:event).order(created_at: :desc)
      scope = scope.unread if unread_only
      notifications = scope.limit(limit)

      success_response(
        notifications.map { |n| serialize_notification(n) },
        message: "Found #{notifications.size} notifications"
      )
    end

    private

    def serialize_notification(notification)
      {
        id: notification.id,
        type: notification.event.type,
        message: safe_message(notification),
        url: safe_url(notification),
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
