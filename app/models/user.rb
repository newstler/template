class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :name, presence: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, presence: true

  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships
  belongs_to :current_team, class_name: "Team", optional: true

  after_create :create_personal_team, unless: :invited?

  def invited?
    Invitation.pending.exists?(email: email)
  end

  private

  def create_personal_team
    team = teams.create!(name: "#{name}'s Team")
    memberships.find_by(team: team).update!(role: :owner, name: name, email: email)
    update!(current_team: team)
  end
end
