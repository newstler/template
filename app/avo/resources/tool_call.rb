class Avo::Resources::ToolCall < Avo::BaseResource
  self.title = :name
  self.includes = [:message]

  self.search = {
    query: -> { query.where("name LIKE ? OR tool_call_id LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id, readonly: true

    field :message, as: :belongs_to, searchable: true

    field :tool_call_id, as: :text, required: true, help: "Unique tool call identifier"
    field :name, as: :text, required: true, help: "Tool/function name"
    field :arguments, as: :code, language: "json", help: "Tool arguments"

    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter Avo::Filters::CreatedAtFilter
  end
end
