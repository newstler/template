class TranslateMessageJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ConversationMessage.find_by(id: message_id)
    return unless message
    return if message.content.blank?

    target_locales = message.conversation.participants
                            .where.not(id: message.user_id)
                            .pluck(:locale)
                            .compact
                            .uniq

    return if target_locales.empty?

    model = Setting.translation_model
    return unless model

    translations = {}
    target_locales.each do |locale|
      prompt = "Translate the following text to #{locale}. Respond with only the translation, no other text.\n\n#{message.content}"
      response = RubyLLM.chat(model: model).ask(prompt)
      translations[locale.to_s] = response.content.strip
    end

    message.update_columns(body_translations: translations)
  end
end
