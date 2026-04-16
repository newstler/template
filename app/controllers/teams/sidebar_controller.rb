class Teams::SidebarController < ApplicationController
  PAGE_SIZE = 10

  before_action :authenticate_user!
  layout false

  def conversations
    offset = params[:offset].to_i
    @conversations = current_user.conversations_in(current_team)
      .includes(:participants, :conversation_messages, :conversation_participants)
      .order(updated_at: :desc)
      .offset(offset)
      .limit(PAGE_SIZE + 1)
      .to_a

    @has_more = @conversations.size > PAGE_SIZE
    @conversations = @conversations.first(PAGE_SIZE)
    @next_offset = offset + PAGE_SIZE
  end

  def chats
    offset = params[:offset].to_i
    @chats = current_user.chats.where(team: current_team)
      .order(updated_at: :desc)
      .offset(offset)
      .limit(PAGE_SIZE + 1)
      .to_a

    @has_more = @chats.size > PAGE_SIZE
    @chats = @chats.first(PAGE_SIZE)
    @next_offset = offset + PAGE_SIZE
  end
end
