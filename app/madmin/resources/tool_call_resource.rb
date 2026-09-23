class ToolCallResource < Madmin::Resource
  # RubyLLM owns the tool-call table; route it through /madmin/tool_calls.
  model RubyLLM::ActiveRecord::ToolCall

  def self.actions
    [ :index, :show ]
  end

  def self.index_path(options = {}) = url_helpers.madmin_tool_calls_path(options)
  def self.show_path(record) = url_helpers.madmin_tool_call_path(record)

  # Attributes
  attribute :id, form: false, index: false
  attribute :name
  attribute :tool_call_id
  attribute :message
  attribute :result
  attribute :approval
  attribute :arguments, field: JsonField, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.searchable_attributes
    [ :name, :tool_call_id ]
  end

  def self.display_name(record)
    record.name
  end
end
