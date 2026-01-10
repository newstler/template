class Avo::Resources::Message < Avo::BaseResource
  self.title = :id
  self.includes = [:chat, :model, :tool_calls]

  self.search = {
    query: -> { query.where("content LIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id, readonly: true

    field :chat, as: :belongs_to, searchable: true
    field :model, as: :belongs_to, searchable: true, help: "AI model used for this message"

    field :role, as: :select, options: { "system" => "system", "user" => "user", "assistant" => "assistant" }, required: true
    field :content, as: :textarea, rows: 5

    # Token tracking
    field :input_tokens, as: :number, readonly: true
    field :output_tokens, as: :number, readonly: true
    field :cached_tokens, as: :number, readonly: true
    field :cache_creation_tokens, as: :number, readonly: true

    field :content_raw, as: :code, language: "json", readonly: true, help: "Full API response"

    field :tool_calls, as: :has_many

    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter Avo::Filters::RoleFilter
    filter Avo::Filters::CreatedAtFilter
  end
end
