class LanguageResource < Madmin::Resource
  def self.actions
    [ :index, :show, :edit ]
  end

  attribute :id, form: false
  attribute :code, form: false, index: true
  attribute :name, form: false, index: true
  attribute :native_name, form: false, index: true
  attribute :enabled, index: true
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.index_attributes
    [ :id, :code, :name, :native_name, :enabled ]
  end

  def self.form_attributes
    [ :enabled ]
  end

  def self.searchable_attributes
    [ :code, :name, :native_name ]
  end

  def self.display_name(record)
    "#{record.name} (#{record.code})"
  end
end
