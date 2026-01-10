class Avo::Filters::CreatedAtFilter < Avo::Filters::DateTimeFilter
  self.name = "Created at"
  self.button_label = "Filter by date"

  def apply(request, query, value)
    case value[:mode]
    when "range"
      query.where(created_at: value[:from]..value[:to])
    when "single"
      query.where("DATE(created_at) = ?", value[:at].to_date)
    else
      query
    end
  end
end
