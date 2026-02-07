class ApplicationController < ActionController::Base
  rate_limit to: 100, within: 1.minute, name: "global"

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_current_user
  before_action :require_onboarding!
  before_action :set_current_team, if: :team_scoped_request?

  private

  def set_current_user
    Current.user = current_user
  end

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
end
