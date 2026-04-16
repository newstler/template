# frozen_string_literal: true

module Mcp
  class UserNotificationsResource < ApplicationResource
    uri "app:///notifications"
    resource_name "User Notifications"
    description "List of notifications for the authenticated user. Use list_notifications tool for authenticated access."
    mime_type "application/json"

    def content
      # Resources don't receive auth headers in fast-mcp
      # Direct users to use the tool instead
      to_json({
        message: "Use the 'list_notifications' tool for authenticated notifications list",
        tool: "list_notifications"
      })
    end
  end
end
