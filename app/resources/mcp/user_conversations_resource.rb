# frozen_string_literal: true

module Mcp
  class UserConversationsResource < ApplicationResource
    uri "app:///conversations"
    resource_name "User Conversations"
    description "List of conversations the authenticated user participates in. Use list_conversations tool for authenticated access."
    mime_type "application/json"

    def content
      to_json({
        message: "Use the 'list_conversations' tool for authenticated conversation list",
        tool: "list_conversations"
      })
    end
  end
end
