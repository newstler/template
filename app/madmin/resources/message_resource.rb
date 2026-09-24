class MessageResource < Madmin::Resource
  # Read-only resource
  def self.actions
    [ :index, :show ]
  end

  # Attributes
  attribute :id, form: false, index: false
  attribute :role
  attribute :content, :text
  attribute :chat
  attribute :finish_reason
  attribute :raw_content, field: JsonField
  attribute :ruby_llm_tool_calls
  attribute :ruby_llm_usages
  attribute :created_at
  attribute :updated_at

  # Associations

  def self.searchable_attributes
    [ :content ]
  end

  def self.display_name(record)
    truncated = record.content.to_s.truncate(50)
    "#{record.role}: #{truncated}"
  end
end
