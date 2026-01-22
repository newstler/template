class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [ :show ]

  # Prevent chat spam
  rate_limit to: 10, within: 1.minute, name: "chats/create", only: :create

  def index
    @chats = current_user.chats.order(created_at: :desc)
  end

  def new
    @chat = current_user.chats.build
    @selected_model = params[:model]
  end

  def create
    return unless prompt.present? || attachments.present?

    @chat = current_user.chats.create!(model: model)
    attachment_paths = store_attachments_temporarily
    ChatResponseJob.perform_later(@chat.id, prompt, attachment_paths)

    redirect_to @chat
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

  def attachments
    params.dig(:chat, :attachments)
  end

  def store_attachments_temporarily
    return [] unless attachments.present?

    attachments.reject(&:blank?).map do |attachment|
      temp_dir = Rails.root.join("tmp", "uploads", SecureRandom.uuid)
      FileUtils.mkdir_p(temp_dir)
      temp_path = temp_dir.join(attachment.original_filename)
      File.binwrite(temp_path, attachment.read)
      temp_path.to_s
    end
  end
end
