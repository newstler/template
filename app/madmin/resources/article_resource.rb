class ArticleResource < Madmin::Resource
  # Read-only: articles are managed through the user interface
  def self.actions
    [ :index, :show ]
  end

  # Attributes
  attribute :id, form: false, index: false
  attribute :title
  attribute :body, index: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :team
  attribute :user

  def self.index_attributes
    [ :id, :title, :created_at ]
  end

  def self.sortable_columns
    super + %w[team_name author_name]
  end

  def self.searchable_attributes
    [ :title ]
  end

  def self.display_name(record)
    record.title.truncate(60)
  end
end
