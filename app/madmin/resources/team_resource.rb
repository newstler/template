class TeamResource < Madmin::Resource
  # Read-only: teams are managed through the user interface
  def self.actions
    [ :index, :show ]
  end

  # Attributes
  attribute :id, form: false
  attribute :name
  attribute :slug
  attribute :api_key
  attribute :stripe_customer_id, form: false
  attribute :subscription_status, form: false
  attribute :current_period_ends_at, form: false
  attribute :created_at, form: false

  # Associations
  attribute :memberships
  attribute :chats

  def self.index_attributes
    [ :id, :name, :slug, :created_at ]
  end

  def self.searchable_attributes
    [ :name, :slug ]
  end

  def self.display_name(record)
    record.name
  end
end
