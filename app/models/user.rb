class User < ApplicationRecord
  include Costable

  has_many :chats, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, on: :update
  validates :locale, inclusion: { in: ->(_) { Language.enabled_codes } }, allow_nil: true

  before_validation :nilify_blank_locale

  def onboarded? = name.present?

  def effective_locale(fallback: :en)
    locale&.to_sym || fallback
  end

  def generate_magic_link_token
    signed_id(purpose: :magic_link, expires_in: 15.minutes)
  end

  # Recalculate total cost from all chats
  def recalculate_total_cost!
    update_column(:total_cost, chats.sum(:total_cost))
  end

  def membership_for(team)
    memberships.find_by(team: team)
  end

  def member_of?(team)
    memberships.exists?(team: team)
  end

  def admin_of?(team)
    memberships.exists?(team: team, role: %w[admin owner])
  end

  def owner_of?(team)
    memberships.exists?(team: team, role: "owner")
  end

  private

  def nilify_blank_locale
    self.locale = nil if locale.blank?
  end
end
