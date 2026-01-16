class UserResource < Madmin::Resource
  # Attributes
  attribute :id, form: false, index: false
  attribute :email, field: GravatarField, index: true, show: true, form: false
  attribute :email  # Regular field for editing
  attribute :name
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :chats

  def self.searchable_attributes
    [ :email, :name ]
  end

  def self.display_name(record)
    record.name.present? ? record.name : record.email
  end
end
