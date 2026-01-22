class Model < ApplicationRecord
  acts_as_model chats_foreign_key: :model_id
  has_many :chats, foreign_key: :model_id

  # Recalculate total cost from all chats
  def recalculate_total_cost!
    update_column(:total_cost, chats.sum(:total_cost))
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

  scope :enabled, -> { where(provider: configured_providers) }

  def self.configured_providers
    distinct.pluck(:provider).select do |provider|
      Rails.application.credentials.dig(provider.to_sym, :api_key).present?
    end
  end
end
