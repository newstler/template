class User < ApplicationRecord
  include Countryable
  include Notifiable

  has_one_attached :avatar

  has_many :chats, dependent: :destroy
  has_many :ai_costs, dependent: :destroy
  has_many :ruby_llm_usages, through: :chats
  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships
  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants

  scope :with_usage_cost, -> {
    select("users.*", "(SELECT COALESCE(SUM(u.total_cost), 0) FROM ruby_llm_usages u " \
                      "JOIN chats c ON u.chat_type = 'Chat' AND u.chat_id = c.id WHERE c.user_id = users.id) AS usage_cost")
  }

  attribute :remove_avatar, :boolean, default: false
  after_save :purge_avatar, if: :remove_avatar

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, on: :update
  validates :locale, inclusion: { in: ->(_) { Language.enabled_codes } }, allow_nil: true
  validates :preferred_currency, inclusion: { in: ->(_) { Setting.enabled_currencies } }, allow_nil: true

  countryable :residence_country_code

  before_validation :nilify_blank_locale

  def onboarded? = name.present?

  def effective_locale(fallback: :en)
    locale&.to_sym || fallback
  end

  def generate_magic_link_token
    signed_id(purpose: :magic_link, expires_in: 15.minutes)
  end


  def conversations_in(team)
    conversations.joins(:conversation_teams).where(conversation_teams: { team_id: team.id })
  end

  # Returns every Noticed::Notification visible to this user:
  # - notifications where this user is the recipient
  # - notifications where a team the user admins is the recipient
  # Team-level notifications are only visible to admins/owners of that team.
  def visible_notifications
    admin_team_ids = memberships.where(role: %w[admin owner]).pluck(:team_id)

    Noticed::Notification.where(
      "(recipient_type = 'User' AND recipient_id = :user_id) OR " \
      "(recipient_type = 'Team' AND recipient_id IN (:team_ids))",
      user_id: id,
      team_ids: admin_team_ids.presence || [ nil ]
    )
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

  def owner?
    memberships.exists?(role: "owner")
  end

  private

  def purge_avatar
    avatar.purge_later
  end

  def nilify_blank_locale
    self.locale = nil if locale.blank?
  end
end
