class Teams::ConversationsController < ApplicationController
  PAGE_SIZE = 20

  before_action :authenticate_user!
  before_action :set_conversation
  before_action :ensure_participant!

  def show
    @participant = @conversation.conversation_participants.find_by!(user: current_user)
    @participant.mark_as_read!

    @messages = scope_for_messages
    @has_older = scope_for_older_messages.any?

    respond_to do |format|
      format.html
      format.turbo_stream do
        response.set_header("X-Has-Older", @has_older.to_s)
        response.set_header("X-Oldest-Id", @messages.first&.id.to_s)
      end
    end
  end

  private

  def set_conversation
    @conversation = current_team.conversations.find(params[:id])
  end

  def ensure_participant!
    unless @conversation.conversation_participants.exists?(user: current_user)
      raise ActiveRecord::RecordNotFound
    end
  end

  def scope_for_messages
    scope = @conversation.conversation_messages.includes(:user).chronologically
    if params[:before].present?
      anchor = @conversation.conversation_messages.find(params[:before])
      scope = scope.where("created_at < ?", anchor.created_at)
    end
    scope.last(PAGE_SIZE)
  end

  def scope_for_older_messages
    return @conversation.conversation_messages.none if @messages.empty?
    @conversation.conversation_messages.where("created_at < ?", @messages.first.created_at)
  end
end
