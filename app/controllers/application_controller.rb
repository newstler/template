class ApplicationController < ActionController::Base
  rate_limit to: 100, within: 1.minute, name: "global"

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_current_user
  before_action :set_locale
  before_action :require_onboarding!
  before_action :set_current_team, if: :team_scoped_request?
  before_action :set_currency

  private

  def require_stripe!
    return if Setting.stripe_configured?

    redirect_to team_root_path(current_team), alert: t("controllers.application.stripe_not_configured")
  end

  def set_current_user
    Current.user = current_user
  end

  def set_locale
    I18n.locale = detect_locale
  end

  def detect_locale
    # 1. User's stored preference
    if current_user&.locale.present?
      return current_user.locale.to_sym
    end

    # 2. Accept-Language header
    if request.headers["Accept-Language"]
      accepted = parse_accept_language(request.headers["Accept-Language"])
      enabled = Language.enabled_codes

      accepted.each do |code|
        return code.to_sym if enabled.include?(code)
      end
    end

    # 3. Default
    I18n.default_locale
  end

  def detected_locale
    I18n.locale
  end
  helper_method :detected_locale

  def set_currency
    Current.currency = detect_currency
  end

  def detect_currency
    # 1. Logged-in user preference
    return current_user.preferred_currency if current_user&.preferred_currency.present?

    # 2. Signed cookie
    cookie_val = cookies.signed[:tmpl_currency]
    if cookie_val.present? && CurrencyConvertible::SUPPORTED_CURRENCIES.include?(cookie_val)
      return cookie_val
    end

    # 3. IP → country → currency
    if (code = current_ip_country)
      mapped = CurrencyConvertible::COUNTRY_CURRENCY[code]
      return mapped if mapped
    end

    # 4. Current team default
    return current_team.default_currency if current_team

    # 5. Platform default
    Setting.default_currency
  end
  helper_method :detect_currency

  # Memoized per-request IP geolocation. Single lookup used by both
  # currency detection and the country_code view helper.
  def current_ip_country
    return @current_ip_country if defined?(@current_ip_country)
    @current_ip_country = nil
    return @current_ip_country if request.remote_ip.blank?

    begin
      result = Geocoder.search(request.remote_ip).first
      @current_ip_country = result&.country_code.to_s.upcase.presence
    rescue StandardError => e
      Rails.logger.debug "[current_ip_country] Geocoder lookup failed: #{e.message}"
      @current_ip_country = nil
    end
  end
  helper_method :current_ip_country

  def set_current_team
    @current_team = current_user&.teams&.find_by(slug: params[:team_slug])

    unless @current_team
      redirect_to teams_path, alert: t("controllers.application.team_not_found")
      return
    end

    Current.team = @current_team
    Current.membership = current_user.membership_for(@current_team)
  end

  def team_scoped_request?
    params[:team_slug].present?
  end

  def personal_context?
    current_user.present? && !team_scoped_request?
  end
  helper_method :personal_context?

  def current_user_teams_for_switcher
    @current_user_teams_for_switcher ||= current_user&.teams&.includes(logo_attachment: :blob)&.order(:name) || []
  end
  helper_method :current_user_teams_for_switcher

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def current_team
    Current.team
  end
  helper_method :current_team

  def current_membership
    Current.membership
  end
  helper_method :current_membership

  # Request-memoized unread notification count. Both the sidebar and
  # the notifications badge partial call this; memoizing here ensures
  # a single COUNT query per request regardless of how many partials
  # render it. We don't rely on a counter cache because Noticed v2
  # persists via insert_all! and bypasses Noticed::Notification callbacks.
  def current_user_unread_notifications_count
    return 0 unless current_user
    @current_user_unread_notifications_count ||= current_user.visible_notifications.unread.count
  end
  helper_method :current_user_unread_notifications_count

  def current_admin
    @current_admin ||= Admin.find_by(id: session[:admin_id]) if session[:admin_id]
  end
  helper_method :current_admin

  def authenticate_user!
    redirect_to new_session_path, alert: t("controllers.application.authenticate_user") unless current_user
  end

  def authenticate_admin!
    redirect_to new_admins_session_path, alert: t("controllers.application.authenticate_admin") unless current_admin
  end

  def require_team_admin!
    unless current_membership&.admin?
      redirect_to team_root_path(current_team), alert: t("controllers.application.admin_required")
    end
  end

  def require_onboarding!
    redirect_to onboarding_path if current_user && !current_user.onboarded?
  end

  def require_subscription!
    return unless current_team
    return if current_team.subscription_active?

    redirect_to team_pricing_path(current_team),
      alert: t("controllers.application.subscription_required")
  end

  def require_chats_enabled!
    return if Setting.ai_chats_enabled?

    redirect_to team_root_path(current_team), alert: t("controllers.application.chats_disabled")
  end

  def parse_accept_language(header)
    header.to_s.split(",").filter_map { |entry|
      lang, quality = entry.strip.split(";")
      code = lang&.strip&.split("-")&.first&.downcase
      q = quality ? quality.strip.delete_prefix("q=").to_f : 1.0
      [ code, q ] if code.present?
    }.sort_by { |_, q| -q }.map(&:first).uniq
  end
end
