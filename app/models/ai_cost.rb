class AiCost < ApplicationRecord
  COST_TYPES = %w[chat embedding translation moderation].freeze

  belongs_to :team, optional: true
  belongs_to :user, optional: true
  belongs_to :trackable, polymorphic: true, optional: true

  validates :cost_type, presence: true, inclusion: { in: COST_TYPES }
  validates :model_id, presence: true

  scope :embeddings, -> { where(cost_type: "embedding") }
  scope :translations, -> { where(cost_type: "translation") }
  scope :moderations, -> { where(cost_type: "moderation") }
  scope :chronologically, -> { order(created_at: :desc) }

  before_save :calculate_cost

  def self.record!(cost_type:, model_id:, input_tokens: 0, output_tokens: 0, team: nil, user: nil, trackable: nil)
    create!(
      cost_type: cost_type,
      model_id: model_id,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      team: team,
      user: user,
      trackable: trackable,
    )
  end

  def formatted_cost
    return nil if cost.nil? || cost.zero?

    if cost < 0.0001
      "<$0.0001"
    else
      "$#{'%.4f' % cost}"
    end
  end

  private

  def calculate_cost
    model_record = Model.find_by(model_id: self.model_id)
    return unless model_record

    pricing = model_record.pricing.dig("text_tokens", "standard") || {}
    input_rate = pricing["input_per_million"].to_f
    output_rate = pricing["output_per_million"].to_f

    input_cost = (input_tokens.to_i / 1_000_000.0) * input_rate
    output_cost = (output_tokens.to_i / 1_000_000.0) * output_rate

    self.cost = input_cost + output_cost
  end
end
