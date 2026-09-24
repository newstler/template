class ModelResource < Madmin::Resource
  # RubyLLM owns the registry table; route it through /madmin/models.
  model RubyLLM::ActiveRecord::Model

  def self.index_path(options = {}) = url_helpers.madmin_models_path(options)
  def self.new_path = url_helpers.new_madmin_model_path
  def self.show_path(record) = url_helpers.madmin_model_path(record)
  def self.edit_path(record) = url_helpers.edit_madmin_model_path(record)

  # Attributes
  attribute :id, form: false, index: false
  attribute :name
  attribute :model_id
  attribute :provider
  attribute :family
  attribute :context_window
  attribute :max_output_tokens
  attribute :knowledge_cutoff
  attribute :modalities, field: JsonField, form: false
  attribute :capabilities, field: JsonField, form: false
  attribute :pricing, field: JsonField, form: false
  attribute :metadata, field: JsonField, form: false
  attribute :model_created_at, form: false
  attribute :unlisted_at, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.searchable_attributes
    [ :name, :model_id, :provider ]
  end

  def self.sortable_columns
    super + %w[chats_count usage_cost]
  end

  def self.display_name(record)
    record.name
  end
end
