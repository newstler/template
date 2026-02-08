class Message < ApplicationRecord
  acts_as_message tool_calls_foreign_key: :message_id
  has_many_attached :attachments
  broadcasts_to ->(message) { "chat_#{message.chat_id}" }, inserts_by: :append, target: "messages"

  after_update_commit :broadcast_message_replacement, if: :assistant?
  before_save :calculate_cost, if: :should_calculate_cost?

  # Update counter caches
  after_create :increment_counters
  after_destroy :decrement_counters
  after_update :update_cost_caches, if: :saved_change_to_cost?

  def broadcast_append_chunk(content)
    broadcast_append_to "chat_#{chat_id}",
      target: "message_#{id}_content",
      partial: "messages/content",
      locals: { content: content }
  end

  def assistant?
    role == "assistant"
  end

  # Calculate cost based on token usage and model pricing
  def calculate_cost
    return unless model_pricing.present?

    pricing = model_pricing.dig("text_tokens", "standard") || {}
    input_rate = pricing["input_per_million"].to_f
    output_rate = pricing["output_per_million"].to_f
    cached_rate = pricing["cached_input_per_million"].to_f

    input_cost = (input_tokens.to_i / 1_000_000.0) * input_rate
    output_cost = (output_tokens.to_i / 1_000_000.0) * output_rate
    cached_cost = (cached_tokens.to_i / 1_000_000.0) * cached_rate

    self.cost = input_cost + output_cost + cached_cost
  end

  # Format cost for display (e.g., "$0.0012" or "<$0.0001")
  def formatted_cost
    return nil if cost.nil? || cost.zero?

    if cost < 0.0001
      "<$0.0001"
    else
      "$#{'%.4f' % cost}"
    end
  end

  private

  def increment_counters
    return unless chat

    Chat.increment_counter(:messages_count, chat.id)
    update_cost_caches
  end

  def decrement_counters
    return unless chat

    Chat.decrement_counter(:messages_count, chat.id)
    chat.recalculate_total_cost!
    chat.user&.recalculate_total_cost!
    chat.model&.recalculate_total_cost!
  end

  def update_cost_caches
    return unless chat

    chat.recalculate_total_cost!
    chat.user&.recalculate_total_cost!
    chat.model&.recalculate_total_cost!
  end

  def model_pricing
    model&.pricing || chat&.model&.pricing
  end

  def should_calculate_cost?
    (input_tokens.present? || output_tokens.present?) && cost_changed_from_default?
  end

  def cost_changed_from_default?
    cost.nil? || cost.zero?
  end

  def broadcast_message_replacement
    broadcast_replace_to "chat_#{chat_id}",
      target: "message_#{id}",
      partial: "messages/message",
      locals: { message: self }
  end
end
