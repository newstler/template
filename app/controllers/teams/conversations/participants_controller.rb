class Teams::Conversations::ParticipantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation
  before_action :ensure_participant!

  def show
    @participant_user = @conversation.participants.find(params[:id])
    @participant_memberships = @participant_user.memberships
      .where(team_id: @conversation.teams.select(:id))
      .includes(:team)
  end

  private

  def set_conversation
    @conversation = current_team.conversations.find(params[:conversation_id])
  end

  def ensure_participant!
    unless @conversation.conversation_participants.exists?(user: current_user)
      raise ActiveRecord::RecordNotFound
    end
  end
end
