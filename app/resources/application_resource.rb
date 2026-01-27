# frozen_string_literal: true

class ApplicationResource < ActionResource::Base
  # Shared helpers for all MCP resources
  #
  # Note: Resources in fast-mcp don't receive request headers,
  # so authentication isn't possible for resources.
  # Resources should either be public or use tools for authenticated access.

  private

  # Resources cannot authenticate - always returns nil
  # Use tools for authenticated operations
  def current_user
    nil
  end

  # Check if user is authenticated (always false for resources)
  def authenticated?
    false
  end

  # Convert data to JSON string
  def to_json(data)
    data.to_json
  end

  # Format timestamps consistently
  def format_timestamp(time)
    time&.iso8601
  end
end
