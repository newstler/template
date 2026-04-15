class AiCostResource < Madmin::Resource
  def self.actions
    [ :index, :show ]
  end

  attribute :id, form: false
  attribute :cost_type, index: true
  attribute :model_id, index: true
  attribute :input_tokens, index: true
  attribute :output_tokens, index: true
  attribute :cost, index: true
  attribute :team, index: true
  attribute :user
  attribute :created_at, form: false

  def self.default_sort_column = "created_at"
  def self.default_sort_direction = "desc"
end
