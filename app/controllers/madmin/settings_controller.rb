module Madmin
  class SettingsController < Madmin::ApplicationController
    def show
      @setting = Setting.instance
    end

    def edit
      @setting = Setting.instance
    end

    def update
      @setting = Setting.instance

      if @setting.update(setting_params)
        redirect_to main_app.madmin_settings_path, notice: t("controllers.madmin.settings.update.notice")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def setting_params
      params.require(:setting).permit(
        :openai_api_key,
        :anthropic_api_key,
        :stripe_secret_key,
        :stripe_publishable_key,
        :stripe_webhook_secret,
        :trial_days,
        :litestream_replica_bucket,
        :litestream_replica_key_id,
        :litestream_replica_access_key,
      )
    end
  end
end
