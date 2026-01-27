# frozen_string_literal: true

# FastMcp - Model Context Protocol for Rails
#
# Transport: Streamable HTTP (MCP spec 2025-03-26)
# - Tool calls via HTTP POST to /mcp/messages
# - Server notifications via SSE at /mcp/sse (optional)
#
# Authentication:
# - API key via x-api-key header for user authentication
#
# Testing with MCP Inspector:
# 1. Start server: bin/dev
# 2. Open MCP Inspector: npx @anthropic-ai/mcp-inspector
# 3. Select "Streamable HTTP" transport
# 4. URL: http://localhost:3000/mcp/messages
# 5. Add header: x-api-key: <your-user-api-key>
# 6. Connect and test tools
#
# All tools inherit from ApplicationTool (ActionTool::Base)
# All resources inherit from ApplicationResource (ActionResource::Base)

require "fast_mcp"

# Patch fast-mcp to support Streamable HTTP transport.
# fast-mcp 1.6.0 sends all responses via SSE and returns empty HTTP bodies.
# This patch returns responses inline in the HTTP POST body, which is what
# MCP Inspector and modern MCP clients expect (Streamable HTTP pattern).
module StreamableHttpTransport
  private

  def process_json_request_with_server(request, server)
    body = request.body.read
    @logger.debug("Request body: #{body}")

    headers = request.env.select { |k, _v| k.start_with?("HTTP_") }
                       .transform_keys { |k| k.sub("HTTP_", "").downcase.tr("_", "-") }

    # Capture the response instead of broadcasting via SSE.
    # Temporarily replace transport's send_message to capture the response.
    captured_response = nil
    original_transport = server.transport

    capturing_transport = Object.new
    capturing_transport.define_singleton_method(:send_message) { |msg| captured_response = msg }
    server.transport = capturing_transport

    server.handle_request(body, headers: headers)

    server.transport = original_transport

    if captured_response
      json_response = captured_response.is_a?(String) ? captured_response : JSON.generate(captured_response)
      [ 200, { "Content-Type" => "application/json" }, [ json_response ] ]
    else
      # No response needed (e.g., notification acknowledgment)
      [ 202, { "Content-Type" => "application/json" }, [ "" ] ]
    end
  end
end

FastMcp::Transports::RackTransport.prepend(StreamableHttpTransport)

FastMcp.mount_in_rails(
  Rails.application,
  name: Rails.application.class.module_parent_name.underscore.dasherize,
  version: "1.0.0",
  path_prefix: "/mcp",
  messages_route: "messages",
  sse_route: "sse"
) do |server|
  Rails.application.config.after_initialize do
    # Register all tool and resource descendants
    server.register_tools(*ApplicationTool.descendants)
    server.register_resources(*ApplicationResource.descendants)
  end
end
