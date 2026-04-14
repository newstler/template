class NoticedNotificationResource < Madmin::Resource
  model Noticed::Notification

  # Read-only resource
  def self.actions
    [ :index, :show ]
  end

  attribute :id, form: false
  attribute :type
  attribute :event_id, form: false
  attribute :recipient_type, form: false
  attribute :recipient_id, form: false
  attribute :read_at, form: false
  attribute :seen_at, form: false
  attribute :created_at, form: false

  def self.display_name(notification)
    "#{notification.type} → #{notification.recipient_type} #{notification.recipient_id}"
  end

  def self.index_attributes
    [ :id, :type, :recipient_type, :read_at, :created_at ]
  end

  def self.show_attributes
    [ :id, :type, :event_id, :recipient_type, :recipient_id, :read_at, :seen_at, :created_at ]
  end

  def self.sortable_columns
    super + %w[type recipient_type read_at]
  end
end
