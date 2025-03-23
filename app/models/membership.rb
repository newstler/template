class Membership < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :team
  belongs_to :added_by, class_name: "Membership", optional: true
  belongs_to :platform_agent_of, class_name: "Team", optional: true
  has_one :invitation, dependent: :destroy

  # We use integer enum for better performance and simpler queries
  enum :role, %i[member owner]

  validates :user_id, uniqueness: { scope: :team_id }, if: :user_id?
  validates :user_email, uniqueness: { scope: :team_id }, if: :user_email?

  scope :platform_agents, -> { where.not(platform_agent_of: nil) }
  scope :humans, -> { where(platform_agent_of: nil) }
  scope :active, -> { where.not(user_id: nil) }
  scope :tombstones, -> { where(user_id: nil).where.not(user_email: nil) }

  before_destroy :ensure_not_last_owner

  def platform_agent?
    platform_agent_of_id?
  end

  def tombstone?
    user_id.nil?
  end

  def create_tombstone
    return if tombstone?

    # Store user info before nullifying
    self.user_name = user.name
    self.user_email = user.email

    # Clear current team if needed
    if user.current_team_id == team_id
      user.update!(current_team: user.teams.where.not(id: team_id).first)
    end

    # Nullify user reference but keep the data
    self.user = nil
    save!
  end

  private

  def ensure_not_last_owner
    return unless owner?
    return unless user_id?
    return unless team.memberships.owners.active.count == 1

    errors.add(:base, "Can't remove the last owner")
    throw :abort
  end
end
