class TranslateContentJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(model_class_name, record_id, source_locale, target_locale)
    record = model_class_name.constantize.find_by(id: record_id)
    return unless record

    attributes = record.class.translatable_attributes
    return if attributes.empty?

    # Collect source content
    source_content = {}
    Mobility.with_locale(source_locale) do
      attributes.each do |attr|
        value = record.send(attr)
        source_content[attr] = value if value.present?
      end
    end

    return if source_content.empty?

    # Skip if all translations already exist for this locale
    if translations_exist?(record, target_locale, source_content.keys)
      return
    end

    # Build translation prompt
    target_language = Language.find_by_code(target_locale)&.name || target_locale
    prompt = build_prompt(source_content, target_language)

    # Call LLM for translation
    response = RubyLLM.chat(model: "gpt-4.1-nano").ask(prompt)
    translated = parse_response(response.content, source_content.keys)

    return unless translated

    # Save translations
    record.skip_translation_callbacks = true
    Mobility.with_locale(target_locale) do
      translated.each do |attr, value|
        record.send("#{attr}=", value)
      end
      record.save!
    end
  ensure
    record&.skip_translation_callbacks = false if record
  end

  private

  def translations_exist?(record, locale, attributes)
    # Query translation tables directly to avoid fallback returning source locale content
    conditions = { translatable_type: record.class.name, translatable_id: record.id, locale: locale.to_s }
    attributes.all? do |attr|
      Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.exists?(conditions.merge(key: attr.to_s)) ||
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation.exists?(conditions.merge(key: attr.to_s))
    end
  end

  def build_prompt(content, target_language)
    json_content = content.to_json
    <<~PROMPT
      Translate the following JSON values to #{target_language}. Keep the JSON keys unchanged. Respond with only valid JSON, no other text.

      #{json_content}
    PROMPT
  end

  def parse_response(response_text, expected_keys)
    # Extract JSON from response (handle possible markdown code blocks)
    json_str = response_text.strip
    json_str = json_str.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "")

    parsed = JSON.parse(json_str)
    result = {}

    expected_keys.each do |key|
      value = parsed[key] || parsed[key.to_s]
      result[key] = value if value.present?
    end

    result.presence
  rescue JSON::ParserError => e
    Rails.logger.warn "TranslateContentJob: Failed to parse LLM response: #{e.message}"
    nil
  end
end
