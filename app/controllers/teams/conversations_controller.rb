class Teams::ConversationsController < ApplicationController
  PAGE_SIZE = 20

  before_action :authenticate_user!
  before_action :set_conversation, only: :show
  before_action :ensure_participant!, only: :show

  def index
    latest = current_team.conversations
      .joins(:conversation_participants)
      .where(conversation_participants: { user: current_user })
      .order(updated_at: :desc)
      .first

    if latest
      redirect_to team_conversation_path(current_team, latest)
    else
      redirect_to new_team_conversation_path(current_team)
    end
  end

  def new
    @conversation = Conversation.new
    @team_members = current_team.users.where.not(id: current_user.id).order(:name)
  end

  def create
    participant_ids = Array(params.dig(:conversation, :participant_ids)).reject(&:blank?)
    participants = current_team.users.where(id: participant_ids).to_a
    participants = ([ current_user ] + participants).uniq

    @conversation = Conversation.create!(title: params.dig(:conversation, :title))
    @conversation.conversation_teams.find_or_create_by!(team: current_team)
    participants.each do |user|
      @conversation.conversation_participants.find_or_create_by!(user: user)
    end

    redirect_to team_conversation_path(current_team, @conversation)
  end

  def show
    @participant = @conversation.conversation_participants.find_by!(user: current_user)
    @participant.mark_as_read!

    @messages = scope_for_messages
    @has_older = scope_for_older_messages.any?
    @conversation_teams = @conversation.teams.to_a
    preload_message_users(@messages)

    response.set_header("X-Has-Older", @has_older.to_s)
    response.set_header("X-Oldest-Id", @messages.first&.id.to_s)
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

  def preload_message_users(messages)
    user_ids = messages.map(&:user_id).uniq
    memberships = Membership.where(user_id: user_ids, team_id: @conversation_teams.map(&:id)).includes(:team)
    @user_memberships = memberships.group_by(&:user_id)
  end

  def scope_for_older_messages
    return @conversation.conversation_messages.none if @messages.empty?
    @conversation.conversation_messages.where("created_at < ?", @messages.first.created_at)
  end
end
