# frozen_string_literal: true

class ApplicationTool < ActionTool::Base
  # Authentication helpers available to all tools
  # Override in subclasses to customize authorization behavior

  class << self
    # Mark a tool as requiring admin privileges
    def admin_only!
      @admin_only = true
    end

    def admin_only?
      @admin_only == true
    end
  end

  private

  # Get current user from API key header
  # fast-mcp passes headers to tool via constructor, available as `headers`
  # Headers are transformed by Rack transport: HTTP_X_API_KEY -> x-api-key
  def current_user
    return @current_user if defined?(@current_user)

    # fast-mcp transforms headers to lowercase with dashes
    api_key = headers["x-api-key"]
    @current_user = User.find_by(api_key: api_key) if api_key.present?
  end

  # Get current team from x-team-slug header
  def current_team
    return @current_team if defined?(@current_team)

    slug = headers["x-team-slug"]

    @current_team = if slug.present?
      current_user&.teams&.find_by(slug: slug)
    elsif !Team.multi_tenant?
      Team.first
    end
  end

  # Get current admin from session (for browser-based requests)
  # Note: Session-based admin auth may not work via MCP - use API keys instead
  def current_admin
    return @current_admin if defined?(@current_admin)

    # Admin auth via MCP would need a separate mechanism
    # For now, this is a placeholder
    @current_admin = nil
  end

  # Execute block with Current.user set for model callbacks
  def with_current_user
    previous_user = Current.user
    Current.user = current_user
    yield
  ensure
    Current.user = previous_user
  end

  # Check if user is authenticated
  def authenticated?
    current_user.present?
  end

  # Check if admin is authenticated
  def admin_authenticated?
    current_admin.present?
  end

  # Require user authentication - raise if not authenticated
  def require_authentication!
    raise FastMcp::Tool::InvalidArgumentsError, "Authentication required. Provide X-API-Key header." unless authenticated?
  end

  # Require admin authentication - raise if not authenticated
  def require_admin!
    raise FastMcp::Tool::InvalidArgumentsError, "Admin authentication required." unless admin_authenticated?
  end

  # Require team context - raise if no team
  def require_team!
    require_authentication!

    unless current_team && current_user.member_of?(current_team)
      raise FastMcp::Tool::InvalidArgumentsError, "Team context required. Provide x-team-slug header."
    end
  end

  # Standard success response format
  def success_response(data, message: nil)
    response = { success: true, data: data }
    response[:message] = message if message
    response
  end

  # Standard error response format
  def error_response(message, code: nil)
    response = { success: false, error: message }
    response[:code] = code if code
    response
  end

  # Format timestamps consistently
  def format_timestamp(time)
    time&.iso8601
  end
end
