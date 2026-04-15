module Madmin
  class ApplicationController < Madmin::BaseController
    before_action :authenticate_admin!
    before_action :set_admin_locale
    helper Madmin::ApplicationHelper
    helper ::DashboardHelper
    helper ::ApplicationHelper

    private

    def set_admin_locale
      I18n.locale = :en
    end

    def authenticate_admin!
      admin = Admin.find_by(id: session[:admin_id]) if session[:admin_id]
      redirect_to main_app.new_admins_session_path, alert: "Please log in as admin" unless admin
    end

    helper_method :current_admin

    def current_admin
      @current_admin ||= Admin.find_by(id: session[:admin_id]) if session[:admin_id]
    end
  end
end
