class Avo::Filters::ProviderFilter < Avo::Filters::SelectFilter
  self.name = "Provider"

  def apply(request, query, value)
    return query if value.blank?

    query.where(provider: value)
  end

  def options
    {
      "openai" => "OpenAI",
      "anthropic" => "Anthropic"
    }
  end
end
