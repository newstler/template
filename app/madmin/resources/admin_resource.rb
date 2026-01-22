class AdminResource < Madmin::Resource
  # Attributes
  attribute :id, form: false, index: false
  attribute :email, field: GravatarField, index: true, show: true, form: false
  attribute :email  # Regular field for editing
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations

  # Member action for sending magic link
  member_action do |record|
    button_to "Send Magic Link",
      "/madmin/admins/#{record.id}/send_magic_link",
      method: :post,
      data: { turbo_confirm: "Send magic link to #{record.email}?" },
      class: "btn btn-primary"
  end

  def self.searchable_attributes
    [ :email ]
  end

  def self.display_name(record)
    record.email
  end
end
