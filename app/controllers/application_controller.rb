class ApplicationController < ActionController::Base
  rate_limit to: 100, within: 1.minute, name: "global"

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_current_user
  before_action :set_locale_from_header
  before_action :require_onboarding!
  before_action :set_current_team, if: :team_scoped_request?

  private

  def set_current_user
    Current.user = current_user
  end

  def set_locale_from_header
    I18n.locale = detect_locale
  end

  def detect_locale
    return I18n.default_locale unless request.headers["Accept-Language"]

    accepted = parse_accept_language(request.headers["Accept-Language"])
    enabled = Language.enabled_codes

    accepted.each do |code|
      return code.to_sym if enabled.include?(code)
    end

    I18n.default_locale
  end

  def detected_locale
    I18n.locale
  end
  helper_method :detected_locale

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
    return if Setting.chats_enabled?

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
