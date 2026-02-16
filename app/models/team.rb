class Team < ApplicationRecord
  include Subscribable

  has_one_attached :logo

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :chats, dependent: :destroy
  has_many :team_languages, dependent: :destroy
  has_many :languages, through: :team_languages
  has_many :articles, dependent: :destroy

  attribute :remove_logo, :boolean, default: false
  after_save :purge_logo, if: :remove_logo

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug
  before_create :generate_api_key
  before_create :start_trial
  after_create :setup_default_language

  def to_param
    slug
  end

  def total_chat_cost
    chats.sum(:total_cost)
  end

  def regenerate_api_key!
    update!(api_key: SecureRandom.hex(32))
  end

  def active_language_codes
    team_languages.active.joins(:language).pluck("languages.code")
  end

  def translation_target_codes(exclude:)
    active_language_codes - Array(exclude)
  end

  def enable_language!(language)
    tl = team_languages.find_or_initialize_by(language: language)
    tl.update!(active: true)
    tl
  end

  def disable_language!(language)
    tl = team_languages.find_by(language: language)
    tl&.update!(active: false)
    tl
  end

  private

  def purge_logo
    logo.purge_later
  end

  def generate_api_key
    self.api_key ||= SecureRandom.hex(32)
  end

  def start_trial
    trial_days = Setting.get(:trial_days) || 30
    return if trial_days.zero?

    self.subscription_status = "trialing"
    self.current_period_ends_at = trial_days.days.from_now
  end

  def setup_default_language
    language = Language.enabled.find_by(code: I18n.locale.to_s) || Language.english
    enable_language!(language) if language
  end

  def generate_slug
    return if slug.present? && !name_changed?

    base_slug = name&.parameterize.presence || "team-#{SecureRandom.alphanumeric(6).downcase}"
    self.slug = base_slug

    counter = 1
    while Team.where.not(id: id).exists?(slug: self.slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
