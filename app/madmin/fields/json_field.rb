class JsonField < Madmin::Field
  def formatted_json(record)
    val = value(record)
    if val.present?
      JSON.pretty_generate(val)
    else
      "{}"
    end
  rescue JSON::GeneratorError
    val.to_s
  end
end
