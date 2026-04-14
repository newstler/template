class Conversation < ApplicationRecord
  belongs_to :team
  belongs_to :subject, polymorphic: true, optional: true

  has_many :conversation_participants, dependent: :destroy
  has_many :participants, through: :conversation_participants, source: :user
  has_many :conversation_messages, dependent: :destroy

  scope :chronologically, -> { order(updated_at: :desc) }

  def self.find_or_create_for(team:, subject: nil, participants: [])
    conversation = where(team: team, subject: subject).first_or_create!
    participants.each do |user|
      conversation.conversation_participants.find_or_create_by!(user: user)
    end
    conversation
  end
end
