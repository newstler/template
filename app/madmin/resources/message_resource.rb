class MessageResource < Madmin::Resource
  # Read-only resource
  def self.actions
    [:index, :show]
  end

  # Attributes
  attribute :id, form: false, index: false
  attribute :role
  attribute :content, :text
  attribute :chat
  attribute :model
  attribute :input_tokens
  attribute :output_tokens
  attribute :cached_tokens
  attribute :cache_creation_tokens
  attribute :cost
  attribute :content_raw, field: JsonField
  attribute :tool_calls
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
