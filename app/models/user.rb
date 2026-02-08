class User < ApplicationRecord
  include Costable

  has_many :chats, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, on: :update

  def onboarded? = name.present?

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
end
