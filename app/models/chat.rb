class Chat < ApplicationRecord
  belongs_to :user, counter_cache: true
  belongs_to :model, optional: true, counter_cache: :chats_count
  acts_as_chat messages_foreign_key: :chat_id

  # Update model counter cache when chat is created/destroyed
  after_create :increment_model_chats_count
  after_destroy :decrement_model_chats_count, :update_costs_on_destroy

  # Recalculate total cost from messages
  def recalculate_total_cost!
    update_column(:total_cost, messages.sum(:cost))
  end

  # Format total cost for display
  def formatted_total_cost
    cost = read_attribute(:total_cost) || 0
    return nil if cost.zero?

    if cost < 0.0001
      "<$0.0001"
    else
      "$#{'%.4f' % cost}"
    end
  end

  private

  def increment_model_chats_count
    Model.increment_counter(:chats_count, model_id) if model_id
  end

  def decrement_model_chats_count
    Model.decrement_counter(:chats_count, model_id) if model_id
  end

  def update_costs_on_destroy
    user&.recalculate_total_cost!
    model&.recalculate_total_cost!
  end
end
