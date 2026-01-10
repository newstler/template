class Avo::Filters::RoleFilter < Avo::Filters::SelectFilter
  self.name = "Role"

  def apply(request, query, value)
    return query if value.blank?

    query.where(role: value)
  end

  def options
    {
      "system" => "System",
      "user" => "User",
      "assistant" => "Assistant"
    }
  end
end
