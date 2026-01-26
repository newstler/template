class Model < ApplicationRecord
  include Costable

  acts_as_model chats_foreign_key: :model_id
  has_many :chats, foreign_key: :model_id

  scope :enabled, -> { where(provider: configured_providers) }

  # Recalculate total cost from all chats
  def recalculate_total_cost!
    update_column(:total_cost, chats.sum(:total_cost))
  end

  def self.configured_providers
    distinct.pluck(:provider).select do |provider|
      Rails.application.credentials.dig(provider.to_sym, :api_key).present?
    end
  end
end
