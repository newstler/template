class Chat < ApplicationRecord
  include Costable

  belongs_to :user
  belongs_to :team, optional: true
  belongs_to :model, optional: true
  acts_as_chat messages_foreign_key: :chat_id

  scope :chronologically, -> { order(created_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }

  after_destroy :update_costs_on_destroy

  # Recalculate total cost from messages
  def recalculate_total_cost!
    update_column(:total_cost, messages.sum(:cost))
  end

  private

  def update_costs_on_destroy
    user&.recalculate_total_cost!
    model&.recalculate_total_cost!
  end
end
