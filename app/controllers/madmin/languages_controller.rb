module Madmin
  class LanguagesController < Madmin::ResourceController
    skip_before_action :set_record, only: :sync

    def sync
      result = Language.sync_from_locale_files!
      parts = []
      parts << "Added #{result[:added].join(', ')}" if result[:added].any?
      parts << "Removed #{result[:removed].join(', ')}" if result[:removed].any?
      notice = parts.any? ? parts.join(". ") : "All locale files already synced"
      redirect_to main_app.madmin_languages_path, notice: notice
    end

    def toggle
      language = Language.find(params[:id])
      language.update!(enabled: !language.enabled?)
      redirect_to main_app.madmin_languages_path, notice: "#{language.name} #{language.enabled? ? 'enabled' : 'disabled'}"
    end
  end
end
