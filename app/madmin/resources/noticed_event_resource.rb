class NoticedEventResource < Madmin::Resource
  model Noticed::Event

  # Read-only resource
  def self.actions
    [ :index, :show ]
  end

  attribute :id, form: false
  attribute :type
  attribute :record_type, form: false
  attribute :record_id, form: false
  attribute :params, form: false
  attribute :notifications_count, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.display_name(event)
    "#{event.type} (#{event.created_at.strftime('%Y-%m-%d %H:%M')})"
  end

  def self.index_attributes
    [ :id, :type, :record_type, :notifications_count, :created_at ]
  end

  def self.show_attributes
    [ :id, :type, :record_type, :record_id, :params, :notifications_count, :created_at, :updated_at ]
  end

  def self.sortable_columns
    super + %w[type record_type notifications_count]
  end
end
