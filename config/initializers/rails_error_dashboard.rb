# frozen_string_literal: true

RailsErrorDashboard.configure do |config|
  # ============================================================================
  # AUTHENTICATION (Always Required - Cannot Be Disabled)
  # ============================================================================

  # Dashboard authentication credentials
  # ⚠️ CHANGE THESE BEFORE PRODUCTION! ⚠️
  # Authentication is ALWAYS enforced in ALL environments (production, development, test)
  config.dashboard_username = ENV.fetch("ERROR_DASHBOARD_USER", "gandalf")
  config.dashboard_password = ENV.fetch("ERROR_DASHBOARD_PASSWORD", "youshallnotpass")

  # Use admin session auth (same as Madmin panel)
  config.authenticate_with = -> {
    if session[:admin_id] && Admin.find_by(id: session[:admin_id])
      true
    else
      redirect_to main_app.new_admins_session_path, allow_other_host: true
    end
  }

  # ============================================================================
  # CORE FEATURES (Always Enabled)
  # ============================================================================

  # Error capture via middleware and Rails.error subscriber
  config.enable_middleware = true
  config.enable_error_subscriber = true

  # User model for error associations
  config.user_model = "User"

  # Error retention policy (days to keep errors before automatic deletion)
  # Set to nil to keep errors forever (not recommended for production)
  # Run cleanup manually: rails error_dashboard:retention_cleanup
  # Or schedule the job: RailsErrorDashboard::RetentionCleanupJob.perform_later
  config.retention_days = 90

  # ============================================================================
  # NOTIFICATION SETTINGS
  # ============================================================================
  # Configure which notification channels you want to use.
  # You can enable/disable any of these at any time by changing true/false.

  # Slack Notifications - DISABLED
  # To enable: Set config.enable_slack_notifications = true and configure webhook URL
  config.enable_slack_notifications = false
  # config.slack_webhook_url = ENV["SLACK_WEBHOOK_URL"]

  # Email Notifications - DISABLED
  # To enable: Set config.enable_email_notifications = true and configure recipients
  config.enable_email_notifications = false
  # config.notification_email_recipients = ENV.fetch("ERROR_NOTIFICATION_EMAILS", "").split(",").map(&:strip)
  # config.notification_email_from = ENV.fetch("ERROR_NOTIFICATION_FROM", "errors@example.com")

  # Discord Notifications - DISABLED
  # To enable: Set config.enable_discord_notifications = true and configure webhook URL
  config.enable_discord_notifications = false
  # config.discord_webhook_url = ENV["DISCORD_WEBHOOK_URL"]

  # PagerDuty Integration - DISABLED
  # To enable: Set config.enable_pagerduty_notifications = true and configure integration key
  config.enable_pagerduty_notifications = false
  # config.pagerduty_integration_key = ENV["PAGERDUTY_INTEGRATION_KEY"]

  # Generic Webhook Notifications - DISABLED
  # To enable: Set config.enable_webhook_notifications = true and configure webhook URLs
  config.enable_webhook_notifications = false
  # config.webhook_urls = ENV.fetch("WEBHOOK_URLS", "").split(",").map(&:strip).reject(&:empty?)

  # Dashboard base URL (used in notification links)
  config.dashboard_base_url = ENV["DASHBOARD_BASE_URL"]

  # ============================================================================
  # PERFORMANCE & SCALABILITY
  # ============================================================================

  # Async Error Logging - DISABLED
  # Errors are logged synchronously (blocking)
  # To enable: Set config.async_logging = true and configure adapter
  config.async_logging = true
  config.async_adapter = :solid_queue

  # Backtrace size limiting (100 lines is industry standard: Rollbar, Airbrake, Bugsnag)
  config.max_backtrace_lines = 100

  # Error Sampling - DISABLED
  # All errors are logged (100% sampling rate)
  # To enable: Set config.sampling_rate < 1.0 (e.g., 0.1 for 10%)
  config.sampling_rate = 1.0

  # Ignored exceptions (skip logging these)
  # config.ignored_exceptions = [
  #   "ActionController::RoutingError",
  #   "ActionController::InvalidAuthenticityToken",
  #   /^ActiveRecord::RecordNotFound/
  # ]

  # ============================================================================
  # DATABASE CONFIGURATION
  # ============================================================================

  # Separate Error Database - DISABLED
  # Errors are stored in your main application database.
  # To enable: Set config.use_separate_database = true and configure database.yml
  # See https://github.com/AnjanJ/rails_error_dashboard/blob/main/docs/guides/DATABASE_OPTIONS.md
  config.use_separate_database = false
  # config.database = :error_dashboard

  # ============================================================================
  # ADVANCED ANALYTICS
  # ============================================================================

  # Baseline Anomaly Alerts - DISABLED
  # To enable: Set config.enable_baseline_alerts = true
  config.enable_baseline_alerts = false
  # config.baseline_alert_threshold_std_devs = 2.0
  # config.baseline_alert_severities = [ :critical, :high ]
  # config.baseline_alert_cooldown_minutes = 120

  # Fuzzy Error Matching - DISABLED
  # To enable: Set config.enable_similar_errors = true
  config.enable_similar_errors = false

  # Co-occurring Errors - DISABLED
  # To enable: Set config.enable_co_occurring_errors = true
  config.enable_co_occurring_errors = false

  # Error Cascade Detection - DISABLED
  # To enable: Set config.enable_error_cascades = true
  config.enable_error_cascades = false

  # Error Correlation Analysis - DISABLED
  # To enable: Set config.enable_error_correlation = true
  config.enable_error_correlation = false

  # Platform Comparison - DISABLED
  # To enable: Set config.enable_platform_comparison = true
  config.enable_platform_comparison = false

  # Occurrence Pattern Detection - DISABLED
  # To enable: Set config.enable_occurrence_patterns = true
  config.enable_occurrence_patterns = false

  # ============================================================================
  # DEVELOPER TOOLS (NEW!)
  # ============================================================================

  # Source Code Integration - DISABLED (NEW!)
  # To enable: Set config.enable_source_code_integration = true
  config.enable_source_code_integration = false

  # Git Blame Integration - DISABLED (NEW!)
  # To enable: Set config.enable_git_blame = true (requires Git installed)
  config.enable_git_blame = false

  # Breadcrumbs - DISABLED
  # To enable: Set config.enable_breadcrumbs = true
  config.enable_breadcrumbs = false
  # config.breadcrumb_buffer_size = 40

  # N+1 Query Detection (analyzes SQL breadcrumbs at display time)
  # Flags repeated query patterns that suggest missing eager loading
  config.enable_n_plus_one_detection = true
  config.n_plus_one_threshold = 3  # Min repetitions to flag (min: 2)

  # System Health Snapshot - DISABLED (NEW!)
  # To enable: Set config.enable_system_health = true
  config.enable_system_health = false

  # Swallowed Exception Detection - DISABLED
  # Requires Ruby 3.3+ (TracePoint(:rescue) not available before 3.3)
  # To enable: Set config.detect_swallowed_exceptions = true
  config.detect_swallowed_exceptions = false
  # config.swallowed_exception_threshold = 0.95

  # Diagnostic Dump - DISABLED
  # On-demand system state snapshot (rake task + dashboard page)
  # To enable: Set config.enable_diagnostic_dump = true
  config.enable_diagnostic_dump = false

  # Process Crash Capture - DISABLED
  # Captures fatal crashes via at_exit hook (written to disk, imported on next boot)
  # To enable: Set config.enable_crash_capture = true
  config.enable_crash_capture = false
  # config.crash_capture_path = "/tmp/my_app_crashes"

  # Repository settings (auto-detected from git remote, optional override)
  # config.repository_url = ENV["REPOSITORY_URL"]  # e.g., "https://github.com/user/repo"
  # config.repository_branch = ENV.fetch("REPOSITORY_BRANCH", "main")  # Default branch

  # ============================================================================
  # INTERNAL LOGGING (Silent by Default)
  # ============================================================================
  # Rails Error Dashboard logging is SILENT by default to keep your logs clean.
  # Enable only for debugging gem issues or troubleshooting setup.

  # Enable internal logging (default: false - silent)
  config.enable_internal_logging = false

  # Log level (default: :silent)
  # Options: :debug, :info, :warn, :error, :silent
  config.log_level = :silent

  # Example: Enable verbose logging for debugging
  # config.enable_internal_logging = true
  # config.log_level = :debug

  # Example: Log only errors (troubleshooting)
  # config.enable_internal_logging = true
  # config.log_level = :error

  # ============================================================================
  # ADDITIONAL CONFIGURATION
  # ============================================================================

  # Custom severity rules (override automatic severity classification)
  # config.custom_severity_rules = {
  #   "PaymentError" => :critical,
  #   "ValidationError" => :low
  # }

  # Enhanced metrics (optional)
  config.app_version = ENV["APP_VERSION"]
  config.git_sha = ENV["GIT_SHA"]
  # config.total_users_for_impact = 10000  # For user impact % calculation

  # Git repository URL for clickable commit links and issue tracking
  # Examples:
  #   GitHub: "https://github.com/username/repo"
  #   GitLab: "https://gitlab.com/username/repo"
  #   Codeberg: "https://codeberg.org/username/repo"
  # config.git_repository_url = ENV["GIT_REPOSITORY_URL"]

  # ============================================================================
  # ISSUE TRACKING (GitHub / GitLab / Codeberg)
  # ============================================================================
  #
  # One switch enables everything: issue creation, auto-create on first
  # occurrence, lifecycle sync (resolve → close, reopen → reopen), platform
  # state mirroring (status, assignees, labels), and comment display.
  #
  # IMPORTANT: When enabled, the dashboard shows platform state instead of
  # internal workflow controls:
  #   - "Mark as Resolved" → replaced by issue open/closed from platform
  #   - Workflow Status → issue state from platform
  #   - Assigned To → assignees from platform (with avatars)
  #   - Priority → labels from platform (with colors)
  #   - Snooze and Mute remain (no platform equivalent)
  #
  # Setup:
  #   1. Create a RED bot account on GitHub/GitLab/Codeberg
  #   2. Generate a token and set RED_BOT_TOKEN env var
  #   3. Set git_repository_url above (already used for source code linking)
  #   4. Enable:
  #
  # config.enable_issue_tracking = true
  # config.issue_tracker_token = ENV["RED_BOT_TOKEN"]
  #
  # Optional overrides:
  # config.issue_tracker_labels = ["bug"]                          # Labels added to new issues
  # config.issue_tracker_auto_create_severities = [:critical, :high]  # Auto-create threshold
  # config.issue_webhook_secret = ENV["ISSUE_WEBHOOK_SECRET"]      # Enables two-way webhook sync
end
