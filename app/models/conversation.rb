class Conversation < ApplicationRecord
  belongs_to :subject, polymorphic: true, optional: true

  has_many :conversation_teams, dependent: :destroy
  has_many :teams, through: :conversation_teams
  has_many :conversation_participants, dependent: :destroy
  has_many :participants, through: :conversation_participants, source: :user
  has_many :conversation_messages, dependent: :destroy

  scope :chronologically, -> { order(updated_at: :asc) }

  # For a B2B conversation spanning multiple teams, returns the team
  # this user should see as "their side" of the conversation — the first
  # team they're a member of. Used to build team-scoped URLs in mailers
  # and views where a single team slug is needed.
  def team_for(user)
    teams.find { |team| user.member_of?(team) } || teams.first
  end

  def self.find_or_create_for(teams:, subject: nil, participants: [])
    teams = Array(teams)
    raise ArgumentError, "teams is required" if teams.empty?

    conversation = joins(:conversation_teams)
      .where(subject: subject)
      .where(conversation_teams: { team_id: teams.map(&:id) })
      .group("conversations.id")
      .having("COUNT(DISTINCT conversation_teams.team_id) = ?", teams.size)
      .first

    conversation ||= create!(subject: subject)

    teams.each { |team| conversation.conversation_teams.find_or_create_by!(team: team) }
    participants.each do |user|
      conversation.conversation_participants.find_or_create_by!(user: user)
    end
    conversation
  end
end
