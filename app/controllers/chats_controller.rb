class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [ :show ]

  def index
    @chats = current_user.chats.order(created_at: :desc)
  end

  def new
    @chat = current_user.chats.build
    @selected_model = params[:model]
  end

  def create
    return unless prompt.present?

    @chat = current_user.chats.create!(model: model)
    ChatResponseJob.perform_later(@chat.id, prompt)

    redirect_to @chat, notice: "Chat was successfully created."
  end

  def show
    @message = @chat.messages.build
  end

  private

  def set_chat
    @chat = current_user.chats.find(params[:id])
  end

  def model
    params[:chat][:model].presence
  end

  def prompt
    params[:chat][:prompt]
  end
end
