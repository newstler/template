class Language < ApplicationRecord
  has_many :team_languages, dependent: :destroy
  has_many :teams, through: :team_languages

  validates :code, presence: true, uniqueness: true,
    inclusion: { in: ->(_) { Language.available_codes }, message: "has no matching i18n yml file" }
  validates :name, presence: true
  validates :native_name, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :by_name, -> { order(:name) }

  before_save :prevent_disabling_english

  after_save :bust_caches

  def self.english
    find_by(code: "en")
  end

  def self.find_by_code(code)
    find_by(code: code)
  end

  def self.enabled_codes
    Rails.cache.fetch("language_enabled_codes", expires_in: 5.minutes) do
      enabled.pluck(:code)
    end
  end

  def self.available_codes
    Rails.cache.fetch("language_available_codes", expires_in: 5.minutes) do
      locale_path = Rails.root.join("config/locales")
      Dir.children(locale_path).filter_map { |entry|
        entry.delete_suffix(".yml") if entry.end_with?(".yml") || File.directory?(locale_path.join(entry))
      }.uniq.sort
    end
  end

  def english?
    code == "en"
  end

  private

  def prevent_disabling_english
    if english? && enabled_changed? && !enabled?
      errors.add(:enabled, "cannot disable English")
      throw :abort
    end
  end

  def bust_caches
    Rails.cache.delete("language_enabled_codes")
    Rails.cache.delete("language_available_codes")
  end
end
