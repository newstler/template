module Madmin
  class ApplicationController < Madmin::BaseController
    before_action :authenticate_admin!
    before_action :set_admin_locale
    helper Madmin::ApplicationHelper
    helper ::DashboardHelper
    helper ::ApplicationHelper

    private

    def set_admin_locale
      I18n.locale = detect_admin_locale
    end

    def detect_admin_locale
      # 1. Admin's stored preference
      if current_admin&.locale.present?
        return current_admin.locale.to_sym
      end

      # 2. Accept-Language header
      if request.headers["Accept-Language"]
        accepted = parse_accept_language(request.headers["Accept-Language"])
        enabled = Language.enabled_codes

        accepted.each do |code|
          return code.to_sym if enabled.include?(code)
        end
      end

      # 3. Platform default language
      Setting.default_language.to_sym
    end

    def parse_accept_language(header)
      header.to_s.split(",").filter_map { |entry|
        lang, quality = entry.strip.split(";")
        code = lang&.strip&.split("-")&.first&.downcase
        q = quality ? quality.strip.delete_prefix("q=").to_f : 1.0
        [ code, q ] if code.present?
      }.sort_by { |_, q| -q }.map(&:first).uniq
    end

    def authenticate_admin!
      admin = Admin.find_by(id: session[:admin_id]) if session[:admin_id]
      redirect_to main_app.new_admins_session_path, alert: t("controllers.madmin.application.authenticate_admin") unless admin
    end

    helper_method :current_admin

    def current_admin
      @current_admin ||= Admin.find_by(id: session[:admin_id]) if session[:admin_id]
    end
  end
end
