class ConversationMessageResource < Madmin::Resource
  # Read-only resource
  def self.actions
    [ :index, :show ]
  end

  # Attributes
  attribute :id, form: false, index: false
  attribute :content, :text
  attribute :flagged_at, form: false
  attribute :flag_reason, form: false
  attribute :body_translations, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :conversation
  attribute :user

  def self.searchable_attributes
    [ :content ]
  end

  def self.display_name(record)
    record.content.to_s.truncate(50).presence || "Message #{record.id[0, 8]}"
  end
end
