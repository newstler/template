class TranslateContentJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(model_class_name, record_id, source_locale, target_locale)
    record = model_class_name.constantize.find_by(id: record_id)
    return unless record

    # Records with a `body_translations` JSON column (e.g. ConversationMessage)
    # are translated in-place — they don't use Mobility.
    return translate_into_json_column(record, source_locale, target_locale) if record.respond_to?(:body_translations)

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
    target_language = Language.find_by(code: target_locale)&.name || target_locale
    prompt = build_prompt(source_content, target_language)

    # Call LLM for translation
    model = Setting.translation_model
    unless model
      Rails.logger.warn("[TranslateContentJob] Skipped: no translation model configured. Set one at /madmin/ai_models")
      return
    end

    response = RubyLLM.chat(model: model).ask(prompt)
    record_cost(record, model, response)
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

    # Re-embed once all translations are done (last job to finish triggers it)
    reembed_if_all_translations_complete(record) if record.class.include?(Embeddable)
  ensure
    record&.skip_translation_callbacks = false if record
  end

  private

  def translate_into_json_column(record, source_locale, target_locale)
    return if record.content.blank?
    return if record.body_translations[target_locale.to_s].present?

    model = Setting.translation_model
    unless model
      Rails.logger.warn("[TranslateContentJob] Skipped: no translation model configured. Set one at /madmin/ai_models")
      return
    end

    target_language = Language.find_by(code: target_locale)&.name || target_locale
    prompt = "Translate the following text from #{source_locale} to #{target_language}. Respond with only the translation, no other text.\n\n#{record.content}"

    response = RubyLLM.chat(model: model).ask(prompt)
    record_cost(record, model, response)
    translation = response.content.to_s.strip
    return if translation.blank?

    translations = record.body_translations.merge(target_locale.to_s => translation)
    record.update_columns(body_translations: translations)
  end

  def reembed_if_all_translations_complete(record)
    return unless record.respond_to?(:team) && record.team.present?

    target_codes = record.team.translation_target_codes(exclude: record.source_locale.to_s)
    return if target_codes.empty?

    attributes = record.class.translatable_attributes
    all_done = target_codes.all? { |locale| translations_exist?(record, locale, attributes) }
    EmbedRecordJob.perform_later(record.class.name, record.id) if all_done
  end

  def record_cost(record, model, response)
    AiCost.record!(
      cost_type: "translation",
      model_id: model,
      input_tokens: response.input_tokens.to_i,
      output_tokens: response.output_tokens.to_i,
      team: record.try(:team),
      user: record.try(:user),
      trackable: record,
    )
  end

  def translations_exist?(record, locale, attributes)
    conditions = { translatable_type: record.class.name, translatable_id: record.id, locale: locale.to_s, key: attributes.map(&:to_s) }
    existing_keys = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(conditions).pluck(:key) |
      Mobility::Backends::ActiveRecord::KeyValue::TextTranslation.where(conditions).pluck(:key)
    (attributes.map(&:to_s) - existing_keys).empty?
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
