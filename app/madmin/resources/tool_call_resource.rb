class ToolCallResource < Madmin::Resource
  # Attributes
  attribute :id, form: false, index: false
  attribute :name
  attribute :tool_call_id
  attribute :message
  attribute :arguments, field: JsonField, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations

  def self.searchable_attributes
    [:name, :tool_call_id]
  end

  def self.display_name(record)
    record.name
  end
end
