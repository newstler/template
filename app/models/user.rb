class User < ApplicationRecord
  include Costable

  has_many :chats, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  before_create :generate_api_key

  def generate_magic_link_token
    signed_id(purpose: :magic_link, expires_in: 15.minutes)
  end

  # Recalculate total cost from all chats
  def recalculate_total_cost!
    update_column(:total_cost, chats.sum(:total_cost))
  end

  # Regenerate API key (useful if compromised)
  def regenerate_api_key!
    generate_api_key
    save!
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

  def generate_api_key
    self.api_key = SecureRandom.hex(32)
  end
end
