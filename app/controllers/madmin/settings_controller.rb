module Madmin
  class SettingsController < Madmin::ApplicationController
    def show
      @setting = Setting.instance
      load_providers
    end

    def update
      @setting = Setting.instance

      if params[:providers].present?
        params[:providers].each do |provider, settings|
          settings.each { |key, value| ProviderCredential.set(provider, key, value) }
        end
        respond_to do |format|
          format.json { head :ok }
          format.html { redirect_to main_app.madmin_settings_path(tab: "providers"), notice: t("controllers.madmin.providers.update.notice") }
        end
      elsif @setting.update(setting_params)
        respond_to do |format|
          format.json { head :ok }
          format.html { redirect_to main_app.madmin_settings_path, notice: t("controllers.madmin.settings.update.notice") }
        end
      else
        respond_to do |format|
          format.json { head :unprocessable_entity }
          format.html do
            load_providers
            render :edit, status: :unprocessable_entity
          end
        end
      end
    end

    private

    def load_providers
      @providers = ProviderCredential.provider_settings
      @credentials = ProviderCredential.all.index_by { |c| [ c.provider, c.key ] }
    end

    def setting_params
      params.require(:setting).permit(
        :ai_chats_enabled,
        :stripe_secret_key,
        :stripe_publishable_key,
        :stripe_webhook_secret,
        :trial_days,
        :litestream_replica_bucket,
        :litestream_replica_key_id,
        :litestream_replica_access_key,
        :currencylayer_api_key,
      )
    end
  end
end
