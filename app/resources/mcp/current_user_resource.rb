# frozen_string_literal: true

module Mcp
  class CurrentUserResource < ApplicationResource
    uri "app:///user/current"
    resource_name "Current User"
    description "Information about the currently authenticated user. Use show_current_user tool for authenticated access."
    mime_type "application/json"

    def content
      # Resources don't receive auth headers in fast-mcp
      # Direct users to use the tool instead
      to_json({
        message: "Use the 'show_current_user' tool for authenticated user info",
        tool: "show_current_user"
      })
    end
  end
end
