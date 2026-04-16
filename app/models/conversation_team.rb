class ConversationTeam < ApplicationRecord
  belongs_to :conversation
  belongs_to :team

  validates :team_id, uniqueness: { scope: :conversation_id }
end
