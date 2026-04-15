class Teams::Conversations::MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation
  before_action :ensure_participant!

  def create
    @message = @conversation.conversation_messages.new(message_params)
    @message.user = current_user

    if @message.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to team_conversation_path(current_team.slug, @conversation) }
      end
    else
      @messages = @conversation.conversation_messages.includes(:user).chronologically.last(Teams::ConversationsController::PAGE_SIZE)
      @has_older = false
      @participant = @conversation.conversation_participants.find_by!(user: current_user)
      render "teams/conversations/show", status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @conversation = current_team.conversations.includes(:participants).find(params[:conversation_id])
  end

  def ensure_participant!
    unless @conversation.conversation_participants.exists?(user: current_user)
      raise ActiveRecord::RecordNotFound
    end
  end

  def message_params
    params.require(:conversation_message).permit(:content, attachments: [])
  end
end
