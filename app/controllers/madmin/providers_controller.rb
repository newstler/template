module Madmin
  class ProvidersController < Madmin::ApplicationController
    def index
      @providers = ProviderCredential.provider_settings
      @credentials = ProviderCredential.all.index_by { |c| [ c.provider, c.key ] }
    end

    def update
      params[:providers]&.each do |provider, settings|
        settings.each do |key, value|
          ProviderCredential.set(provider, key, value)
        end
      end

      redirect_to main_app.madmin_providers_path, notice: t("controllers.madmin.providers.update.notice")
    end
  end
end
