class LanguageResource < Madmin::Resource
  attribute :id, form: false
  attribute :code
  attribute :name
  attribute :native_name
  attribute :enabled
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.index_attributes
    [ :id, :code, :name, :native_name, :enabled ]
  end

  def self.form_attributes
    [ :code, :name, :native_name, :enabled ]
  end

  def self.searchable_attributes
    [ :code, :name, :native_name ]
  end

  def self.display_name(record)
    "#{record.name} (#{record.code})"
  end
end
