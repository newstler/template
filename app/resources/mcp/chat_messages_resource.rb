# frozen_string_literal: true

module Mcp
  class ChatMessagesResource < ApplicationResource
    uri "app:///chats/{chat_id}/messages"
    resource_name "Chat Messages"
    description "Messages in a specific chat. Use list_messages tool for authenticated access."
    mime_type "application/json"

    def content(chat_id:)
      # Resources don't receive auth headers in fast-mcp
      # Direct users to use the tool instead
      to_json({
        message: "Use the 'list_messages' tool for authenticated message access",
        tool: "list_messages",
        arguments: { chat_id: chat_id }
      })
    end
  end
end
