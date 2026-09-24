class AiCost < ApplicationRecord
  COST_TYPES = %w[embedding translation moderation].freeze

  belongs_to :team, optional: true
  belongs_to :user, optional: true
  belongs_to :trackable, polymorphic: true, optional: true

  validates :cost_type, presence: true, inclusion: { in: COST_TYPES }
  validates :model_id, presence: true

  scope :embeddings, -> { where(cost_type: "embedding") }
  scope :translations, -> { where(cost_type: "translation") }
  scope :moderations, -> { where(cost_type: "moderation") }
  scope :chronologically, -> { order(created_at: :desc) }

  # Records a standalone (non-chat) RubyLLM call. Chat spend lives in ruby_llm_usages.
  def self.record_response!(cost_type:, model_id:, response:, team: nil, user: nil, trackable: nil)
    create!(
      cost_type:, model_id:, team:, user:, trackable:,
      input_tokens: response.tokens.input.to_i,
      output_tokens: response.tokens.output.to_i,
      cost: response.cost&.total.to_d,
    )
  end
end
