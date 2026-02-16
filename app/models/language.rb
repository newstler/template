class Language < ApplicationRecord
  has_many :team_languages, dependent: :destroy
  has_many :teams, through: :team_languages

  validates :code, presence: true, uniqueness: true,
    inclusion: { in: ->(_) { Language.available_codes }, message: "has no matching i18n yml file" }
  validates :name, presence: true
  validates :native_name, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :by_name, -> { order(:name) }

  after_save :bust_caches

  def self.sync_from_locale_files!
    Rails.cache.delete("language_available_codes")
    codes = available_codes
    existing_codes = pluck(:code)

    # Add new languages
    added = codes - existing_codes
    added.each do |code|
      name = I18n.t("language_name", locale: code, default: code.upcase)
      native_name = I18n.t("native_name", locale: code, default: code.upcase)
      create!(code: code, name: name, native_name: native_name)
    end

    removed_codes = existing_codes - codes
    where(code: removed_codes).destroy_all if removed_codes.any?

    { added: added, removed: removed_codes }
  end

  def self.english
    find_by(code: "en")
  end

  def self.enabled_codes
    Rails.cache.fetch("language_enabled_codes", expires_in: 5.minutes) do
      enabled.pluck(:code)
    end
  end

  def self.available_codes
    Rails.cache.fetch("language_available_codes", expires_in: 1.hour) do
      locale_path = Rails.root.join("config/locales")
      Dir.children(locale_path).filter_map { |entry|
        entry.delete_suffix(".yml") if entry.end_with?(".yml") || File.directory?(locale_path.join(entry))
      }.uniq.sort
    end
  end

  def localized_name
    I18n.t("languages.#{code}", default: name)
  end

  def english?
    code == "en"
  end

  private

  def bust_caches
    Rails.cache.delete("language_enabled_codes")
    Rails.cache.delete("language_available_codes")
  end
end
