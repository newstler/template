# frozen_string_literal: true

module Mcp
  class UserChatsResource < ApplicationResource
    uri "app:///chats"
    resource_name "User Chats"
    description "List of all chats for the authenticated user. Use list_chats tool for authenticated access."
    mime_type "application/json"

    def content
      # Resources don't receive auth headers in fast-mcp
      # Direct users to use the tool instead
      to_json({
        message: "Use the 'list_chats' tool for authenticated chat list",
        tool: "list_chats"
      })
    end
  end
end
