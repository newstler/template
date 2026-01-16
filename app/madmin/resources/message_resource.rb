class MessageResource < Madmin::Resource
  # Attributes
  attribute :id, form: false, index: false
  attribute :role, :select, collection: [ "system", "user", "assistant" ]
  attribute :content, :text
  attribute :chat
  attribute :model
  attribute :input_tokens, form: false
  attribute :output_tokens, form: false
  attribute :cached_tokens, form: false
  attribute :cache_creation_tokens, form: false
  attribute :cost, form: false
  attribute :content_raw, field: JsonField, form: false
  attribute :tool_calls
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations

  def self.searchable_attributes
    [ :content ]
  end

  def self.display_name(record)
    truncated = record.content.to_s.truncate(50)
    "#{record.role}: #{truncated}"
  end
end
