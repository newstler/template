class Team < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :platform_agents, -> { platform_agents }, class_name: "Membership"

  validates :name, presence: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, presence: true

  before_create :set_time_zone

  def primary_contact
    memberships.owners.order(created_at: :asc).first&.user
  end

  def remove_member(user)
    membership = memberships.find_by!(user: user)

    # Can't remove the last owner
    if membership.owner? && memberships.owners.active.count == 1
      raise "Can't remove the last owner"
    end

    # Just nullify the user - name/email are already set from creation
    membership.update!(user: nil)

    # Update user's current team if needed
    if user.current_team_id == id
      user.update!(current_team: user.teams.first)
    end

    user.invalidate_ability_cache
  end

  private

  def set_time_zone
    self.time_zone ||= creator&.time_zone
  end
end
