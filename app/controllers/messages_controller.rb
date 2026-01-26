class MessagesController < ApplicationController
  include Attachable

  before_action :authenticate_user!
  before_action :set_chat

  # AI calls are expensive - strict limits
  rate_limit to: 20, within: 1.minute, name: "messages/short", only: :create
  rate_limit to: 100, within: 1.hour, name: "messages/long", only: :create

  def create
    return unless content.present? || attachments.present?

    attachment_paths = store_attachments_temporarily(attachments)
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
end
