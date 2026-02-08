# frozen_string_literal: true

module Middleware
  # Blocks known malicious request paths (WordPress exploits, PHP files, etc.)
  # before they reach the Rails router. Runs early in the middleware stack
  # for efficiency.
  class MaliciousPathBlocker
    BLOCKED_PATTERNS = [
      # WordPress
      /wp-admin/i, /wp-includes/i, /wp-content/i, /wp-login/i,
      /xmlrpc\.php/i, /wp-config/i,
      # PHP files
      /\.php$/i, /\.php\//i,
      # Common exploit paths
      /\.env$/i, /\.git/i, /\.svn/i,
      /phpinfo/i, /phpmyadmin/i,
      /admin\.php/i, /setup\.php/i,
      # Path traversal
      /\.\.\//
    ].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      path = env["PATH_INFO"].to_s

      if blocked_path?(path)
        log_blocked_request(env, path)
        [ 403, { "Content-Type" => "text/plain" }, [ "Forbidden" ] ]
      else
        @app.call(env)
      end
    end

    private

    def blocked_path?(path)
      BLOCKED_PATTERNS.any? { |pattern| path.match?(pattern) }
    end

    def log_blocked_request(env, path)
      ip = env["HTTP_X_FORWARDED_FOR"]&.split(",")&.first&.strip || env["REMOTE_ADDR"]
      Rails.logger.warn "[MaliciousPathBlocker] Blocked: #{path} from #{ip}"
    end
  end
end
