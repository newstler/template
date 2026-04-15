class ConversationResource < Madmin::Resource
  # Read-only resource
  def self.actions
    [ :index, :show ]
  end

  # Attributes
  attribute :id, form: false, index: false
  attribute :title
  attribute :subject_type, form: false
  attribute :subject_id, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :teams
  attribute :conversation_messages
  attribute :conversation_participants

  def self.searchable_attributes
    [ :title ]
  end

  def self.display_name(record)
    record.title.presence || "Conversation #{record.id[0, 8]}"
  end
end
