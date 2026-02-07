module Madmin
  class PricesController < Madmin::ApplicationController
    def show
      @setting = Setting.instance
      @prices = @setting.stripe_secret_key.present? ? Price.all : []
    rescue Stripe::AuthenticationError, Stripe::APIConnectionError
      @prices = []
    end

    def sync
      Price.clear_cache
      redirect_to main_app.madmin_prices_path, notice: t("controllers.madmin.prices.sync.notice")
    end
  end
end
