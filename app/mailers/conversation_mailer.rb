class ConversationMailer < ApplicationMailer
  def new_message
    @message = params[:message]
    @conversation = @message.conversation
    @recipient = params[:recipient]
    mail(to: @recipient.email, subject: I18n.t("conversation_mailer.new_message.subject"))
  end

  def messages_digest
    @recipient = params[:recipient]
    @conversations = params[:conversations]
    @messages_by_conversation = @conversations.each_with_object({}) do |c, hash|
      hash[c] = c.conversation_messages.chronologically.last(3)
    end
    mail(to: @recipient.email, subject: I18n.t("conversation_mailer.messages_digest.subject"))
  end
end
