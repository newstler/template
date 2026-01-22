class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat

  # AI calls are expensive - strict limits
  rate_limit to: 20, within: 1.minute, name: "messages/short", only: :create
  rate_limit to: 100, within: 1.hour, name: "messages/long", only: :create

  def create
    return unless content.present? || attachments.present?

    # Store attachments in a temporary location for the background job
    attachment_paths = store_attachments_temporarily

    ChatResponseJob.perform_later(@chat.id, content, attachment_paths)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @chat }
    end
  end

  private

  def set_chat
    @chat = current_user.chats.find(params[:chat_id])
  end

  def content
    params.dig(:message, :content) || ""
  end

  def attachments
    params.dig(:message, :attachments)
  end

  def store_attachments_temporarily
    return [] unless attachments.present?

    attachments.reject(&:blank?).map do |attachment|
      # Create a temporary file that persists until the job processes it
      temp_dir = Rails.root.join("tmp", "uploads", SecureRandom.uuid)
      FileUtils.mkdir_p(temp_dir)
      temp_path = temp_dir.join(attachment.original_filename)
      File.binwrite(temp_path, attachment.read)
      temp_path.to_s
    end
  end
end
