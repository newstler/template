# frozen_string_literal: true

class ApplicationTool < ActionTool::Base
  # Authentication helpers available to all tools
  # Override in subclasses to customize authorization behavior
  #
  # Authentication flow:
  #   1. x-api-key header → find Team
  #   2. x-user-email header (optional) → find User, verify team membership
  #
  # Tools that only need team context use require_team!
  # Tools that need user context use require_user! or with_current_user

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

  # Primary auth: Team from API key
  def current_team
    return @current_team if defined?(@current_team)

    api_key = headers["x-api-key"]
    @current_team = Team.find_by(api_key: api_key) if api_key.present?
  end

  # Secondary: User from email header (must be team member)
  def current_user
    return @current_user if defined?(@current_user)
    return @current_user = nil unless current_team

    email = headers["x-user-email"]
    if email.present?
      user = User.find_by(email: email)
      @current_user = user if user&.member_of?(current_team)
    end
    @current_user
  end

  # Get current admin from session (for browser-based requests)
  # Note: Session-based admin auth may not work via MCP - use API keys instead
  def current_admin
    return @current_admin if defined?(@current_admin)

    # Admin auth via MCP would need a separate mechanism
    # For now, this is a placeholder
    @current_admin = nil
  end

  # Execute block with Current.user and Current.team set for model callbacks
  def with_current_user
    require_user!
    previous_user = Current.user
    previous_team = Current.team
    Current.user = current_user
    Current.team = current_team
    yield
  ensure
    Current.user = previous_user
    Current.team = previous_team
  end

  # Check if team is authenticated via API key
  def team_authenticated?
    current_team.present?
  end

  # Check if user is authenticated (team + user email)
  def authenticated?
    current_user.present?
  end

  # Check if admin is authenticated
  def admin_authenticated?
    current_admin.present?
  end

  # Require team authentication - raise if no valid API key
  def require_team!
    unless team_authenticated?
      raise FastMcp::Tool::InvalidArgumentsError, "Valid x-api-key header required."
    end
  end

  # Require user authentication - raise if no valid user
  def require_user!
    require_team!
    unless authenticated?
      raise FastMcp::Tool::InvalidArgumentsError, "x-user-email header required (must be team member)."
    end
  end

  # Legacy alias for backwards compatibility
  def require_authentication!
    require_user!
  end

  # Require admin authentication - raise if not authenticated
  def require_admin!
    raise FastMcp::Tool::InvalidArgumentsError, "Admin authentication required." unless admin_authenticated?
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
