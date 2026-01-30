class Membership < ApplicationRecord
  ROLES = %w[member admin owner].freeze

  belongs_to :user
  belongs_to :team
  belongs_to :invited_by, class_name: "User", optional: true

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :team_id }

  def owner?
    role == "owner"
  end

  def admin?
    role.in?(%w[admin owner])
  end

  def member?
    role == "member"
  end
end
