module Madmin
  class LanguagesController < Madmin::ResourceController
    skip_before_action :set_record, only: [ :sync, :update_currency, :toggle_currency, :bulk_toggle, :bulk_toggle_currency ]

    before_action :load_setting, only: :index

    def sync
      result = Language.sync_from_locale_files!
      parts = []
      parts << "Added #{result[:added].join(', ')}" if result[:added].any?
      parts << "Removed #{result[:removed].join(', ')}" if result[:removed].any?
      notice = parts.any? ? parts.join(". ") : "All locale files already synced"
      redirect_to main_app.madmin_languages_path, notice: notice
    end

    def toggle
      @language = Language.find(params[:id])
      @language.update!(enabled: !@language.enabled?)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to main_app.madmin_languages_path }
      end
    end

    def bulk_toggle
      enable = params[:enable] == "true"
      Language.where.not(code: "en").update_all(enabled: enable)
      redirect_to main_app.madmin_languages_path, notice: "All languages #{enable ? 'enabled' : 'disabled'}"
    end

    def bulk_toggle_currency
      enable = params[:enable] == "true"
      codes = enable ? CurrencyConvertible::SUPPORTED_CURRENCIES.join(",") : ""
      Setting.instance.update!(enabled_currencies: codes)
      redirect_to main_app.madmin_languages_path(tab: "currencies"), notice: "All currencies #{enable ? 'enabled' : 'disabled'}"
    end

    def toggle_currency
      @code = params[:code]
      Setting.toggle_currency!(@code)
      @enabled = Setting.currency_enabled?(@code)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to main_app.madmin_languages_path(tab: "currencies") }
      end
    end

    def update_currency
      @setting = Setting.instance
      if @setting.update(params.require(:setting).permit(:default_currency))
        respond_to do |format|
          format.json { head :ok }
          format.html { redirect_to main_app.madmin_languages_path(tab: "currencies"), notice: "Currency settings updated" }
        end
      else
        respond_to do |format|
          format.json { head :unprocessable_entity }
          format.html { redirect_to main_app.madmin_languages_path(tab: "currencies") }
        end
      end
    end

    private

    def load_setting
      @setting = Setting.instance
    end
  end
end
