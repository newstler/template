class ModelResource < Madmin::Resource
  # Attributes
  attribute :id, form: false, index: false
  attribute :name
  attribute :model_id
  attribute :provider, :select, collection: ["openai", "anthropic"]
  attribute :family
  attribute :context_window
  attribute :max_output_tokens
  attribute :knowledge_cutoff
  attribute :modalities, field: JsonField, form: false
  attribute :capabilities, field: JsonField, form: false
  attribute :pricing, field: JsonField, form: false
  attribute :metadata, field: JsonField, form: false
  attribute :model_created_at, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations

  def self.searchable_attributes
    [:name, :model_id, :provider]
  end

  def self.display_name(record)
    record.name
  end
end
