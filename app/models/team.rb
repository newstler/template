class Team < ApplicationRecord
  include Subscribable

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :chats, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug
  before_create :generate_api_key
  before_create :start_trial

  def to_param
    slug
  end

  def total_chat_cost
    chats.sum(:total_cost)
  end

  def regenerate_api_key!
    update!(api_key: SecureRandom.hex(32))
  end

  private

  def generate_api_key
    self.api_key ||= SecureRandom.hex(32)
  end

  def start_trial
    trial_days = Setting.get(:trial_days) || 30
    return if trial_days.zero?

    self.subscription_status = "trialing"
    self.current_period_ends_at = trial_days.days.from_now
  end

  def generate_slug
    return if slug.present? && !name_changed?

    base_slug = name&.parameterize
    self.slug = base_slug

    counter = 1
    while Team.where.not(id: id).exists?(slug: self.slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
