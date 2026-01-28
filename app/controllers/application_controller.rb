class ApplicationController < ActionController::Base
  rate_limit to: 100, within: 1.minute, name: "global"

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_current_user

  private

  def set_current_user
    Current.user = current_user
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

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
end
