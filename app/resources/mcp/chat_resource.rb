# frozen_string_literal: true

module Mcp
  class ChatResource < ApplicationResource
    uri "app:///chats/{id}"
    resource_name "Chat"
    description "A single chat conversation with all messages. Use show_chat tool for authenticated access."
    mime_type "application/json"

    def content(id:)
      # Resources don't receive auth headers in fast-mcp
      # Direct users to use the tool instead
      to_json({
        message: "Use the 'show_chat' tool for authenticated chat access",
        tool: "show_chat",
        arguments: { id: id }
      })
    end
  end
end
