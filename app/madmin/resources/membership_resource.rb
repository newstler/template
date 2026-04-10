class MembershipResource < Madmin::Resource
  # Read-only: memberships are managed through team invitations
  def self.actions
    [ :index, :show ]
  end

  # Attributes
  attribute :id, form: false, index: false
  attribute :role
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :user
  attribute :team

  def self.index_attributes
    [ :id, :role, :created_at ]
  end

  def self.sortable_columns
    super + %w[user_name team_name]
  end

  def self.searchable_attributes
    []
  end

  def self.display_name(record)
    "#{record.user&.name || record.user&.email} in #{record.team&.name}"
  end
end
