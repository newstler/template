# frozen_string_literal: true

MissionControl::Jobs.http_basic_auth_enabled = false

Rails.application.config.after_initialize do
  MissionControl::Jobs::ApplicationController.class_eval do
    before_action :authenticate_admin!

    private

    def authenticate_admin!
      return if session[:admin_id] && Admin.find_by(id: session[:admin_id])
      redirect_to main_app.new_admins_session_path, allow_other_host: true
    end
  end
end
