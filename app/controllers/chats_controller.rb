class ChatsController < ApplicationController
  include Attachable

  before_action :authenticate_user!
  before_action :require_chats_enabled!, only: [ :index, :new, :create ]
  before_action :set_chat, only: [ :show ]

  # Prevent chat spam
  rate_limit to: 10, within: 1.minute, name: "chats/create", only: :create

  def index
    @chats = current_user.chats.where(team: current_team).includes(:model, :messages).recent
  end

  def new
    @chat = current_user.chats.build(team: current_team)
    @selected_model = params[:model]
  end

  def create
    return unless prompt.present? || attachments.present?

    @chat = current_user.chats.create!(model: model, team: current_team)
    attachment_paths = store_attachments_temporarily(attachments)
    ChatResponseJob.perform_later(@chat.id, prompt, attachment_paths)

    redirect_to team_chat_path(current_team, @chat)
  end

  def show
    @message = @chat.messages.build
  end

  private

  def set_chat
    @chat = current_user.chats.where(team: current_team).includes(messages: [ :tool_calls, { attachments_attachments: :blob } ]).find(params[:id])
  end

  def model
    params[:chat][:model].presence
  end

  def prompt
    params[:chat][:prompt]
  end

  def attachments
    params.dig(:chat, :attachments)
  end
end
