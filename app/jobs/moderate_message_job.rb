class ModerateMessageJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ConversationMessage.find_by(id: message_id)
    return unless message
    return if message.content.blank?
    # Regex gate has already run synchronously in the model's
    # before_validation callback. If a message reaches the LLM stage
    # flagged, it was caught there — skip.
    return if message.flagged_at.present?

    model = Setting.moderation_model
    return unless model

    prompt = <<~PROMPT
      Does the following message attempt to share off-platform contact information
      (phone, email, messenger handle, or URL)? Reply with JSON: {"flagged": bool, "reason": string}

      Message:
      #{message.content}
    PROMPT

    response = RubyLLM.chat(model: model).ask(prompt)
    record_cost(message, model, response)
    parsed = begin
      JSON.parse(response.content)
    rescue StandardError
      nil
    end
    return unless parsed.is_a?(Hash) && parsed["flagged"] == true

    message.update_columns(flagged_at: Time.current, flag_reason: "llm:#{parsed['reason']}")
  end

  private

  def record_cost(message, model, response)
    AiCost.record!(
      cost_type: "moderation",
      model_id: model,
      input_tokens: response.input_tokens.to_i,
      output_tokens: response.output_tokens.to_i,
      team: message.conversation&.teams&.first,
      user: message.user,
      trackable: message,
    )
  end
end
