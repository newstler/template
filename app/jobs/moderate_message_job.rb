class ModerateMessageJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ConversationMessage.find_by(id: message_id)
    return unless message
    return if message.content.blank?

    patterns = if message.class.respond_to?(:moderation_patterns)
      message.class.moderation_patterns
    else
      ModeratableMessage::DEFAULT_PATTERNS
    end
    pattern_hit = patterns.find { |p| message.content.match?(p) }
    if pattern_hit
      message.update_columns(
        flagged_at: Time.current,
        flag_reason: "pattern_match:#{pattern_hit.source[0, 50]}"
      )
      return
    end

    model = Setting.moderation_model
    return unless model

    prompt = <<~PROMPT
      Does the following message attempt to share off-platform contact information
      (phone, email, messenger handle, or URL)? Reply with JSON: {"flagged": bool, "reason": string}

      Message:
      #{message.content}
    PROMPT

    response = RubyLLM.chat(model: model).ask(prompt)
    parsed = begin
      JSON.parse(response.content)
    rescue StandardError
      nil
    end
    return unless parsed.is_a?(Hash) && parsed["flagged"] == true

    message.update_columns(flagged_at: Time.current, flag_reason: "llm:#{parsed['reason']}")
  end
end
