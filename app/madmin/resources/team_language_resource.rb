class TeamLanguageResource < Madmin::Resource
  # Read-only: team languages are managed via the user-facing team settings.
  def self.actions
    [ :index, :show ]
  end

  # Attributes
  attribute :id, form: false, index: false
  attribute :active
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :team
  attribute :language

  def self.index_attributes
    [ :id, :active, :created_at ]
  end

  def self.sortable_columns
    super + %w[team_name language_name active]
  end

  def self.searchable_attributes
    []
  end

  def self.display_name(record)
    "#{record.team&.name} — #{record.language&.name}"
  end
end
