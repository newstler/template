class Chat < ApplicationRecord
  belongs_to :user
  belongs_to :team, optional: true
  acts_as_chat

  scope :chronologically, -> { order(updated_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_usage_cost, -> {
    select("chats.*", "(SELECT COALESCE(SUM(u.total_cost), 0) FROM ruby_llm_usages u " \
                      "WHERE u.chat_type = 'Chat' AND u.chat_id = chats.id) AS usage_cost")
  }
end
