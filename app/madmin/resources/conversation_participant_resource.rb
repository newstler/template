class ConversationParticipantResource < Madmin::Resource
  # Read-only: participants are added/removed via the user-facing conversation UI.
  def self.actions
    [ :index, :show ]
  end

  # Attributes
  attribute :id, form: false, index: false
  attribute :last_read_at, form: false
  attribute :last_notified_at, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :conversation
  attribute :user

  def self.index_attributes
    [ :id, :last_read_at, :last_notified_at, :created_at ]
  end

  def self.sortable_columns
    super + %w[user_name conversation_title]
  end

  def self.searchable_attributes
    []
  end

  def self.display_name(record)
    "#{record.user&.name || record.user&.email} in #{record.conversation&.title.presence || "Conv ##{record.conversation_id.to_s[0, 8]}"}"
  end
end
