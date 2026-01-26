class ChatResource < Madmin::Resource
  # Read-only resource
  def self.actions
    [ :index, :show ]
  end

  # Attributes
  attribute :id, form: false, index: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :user
  attribute :model
  attribute :messages

  def self.searchable_attributes
    []  # Custom search in controller
  end

  def self.display_name(record)
    "Chat with #{record.user.email}" if record.user
  end
end
