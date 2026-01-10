class Avo::Resources::Model < Avo::BaseResource
  self.title = :name
  self.includes = []

  self.search = {
    query: -> { query.where("name LIKE ? OR model_id LIKE ? OR provider LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id, readonly: true

    field :name, as: :text, required: true, sortable: true
    field :model_id, as: :text, required: true, help: "Model identifier (e.g., gpt-4, claude-3-5-sonnet)"
    field :provider, as: :select, options: { "openai" => "OpenAI", "anthropic" => "Anthropic" }, required: true

    field :family, as: :text, help: "Model family (e.g., GPT-4, Claude 3.5)"

    field :context_window, as: :number, help: "Maximum context window size"
    field :max_output_tokens, as: :number, help: "Maximum output tokens"
    field :knowledge_cutoff, as: :date, help: "Knowledge cutoff date"

    field :modalities, as: :code, language: "json", help: "Supported modalities (text, image, etc.)"
    field :capabilities, as: :code, language: "json", help: "Model capabilities"
    field :pricing, as: :code, language: "json", help: "Pricing information"
    field :metadata, as: :code, language: "json", help: "Additional metadata"

    field :model_created_at, as: :date_time, readonly: true, help: "When model was released"
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter Avo::Filters::ProviderFilter
  end

  def actions
    action Avo::Actions::RefreshModels
  end
end
