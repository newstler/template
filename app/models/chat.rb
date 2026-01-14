class Chat < ApplicationRecord
  belongs_to :user
  acts_as_chat messages_foreign_key: :chat_id

  # Calculate total cost for all messages in the chat
  def total_cost
    messages.sum(:cost)
  end

  # Format total cost for display
  def formatted_total_cost
    cost = total_cost
    return nil if cost.nil? || cost.zero?

    if cost < 0.0001
      "<$0.0001"
    else
      "$#{'%.4f' % cost}"
    end
  end
end
