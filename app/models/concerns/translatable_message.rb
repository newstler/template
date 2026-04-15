module TranslatableMessage
  extend ActiveSupport::Concern

  included do
    after_create_commit :enqueue_message_translations
  end

  # The locale the message was authored in. Used as the source locale
  # for translation. Defaults to the sender's locale, falling back to
  # I18n.default_locale.
  def source_locale
    user&.locale.presence || I18n.default_locale.to_s
  end

  private

  def enqueue_message_translations
    return if content.blank?
    team = conversation&.team
    return unless team

    target_codes = team.translation_target_codes(exclude: source_locale.to_s)
    return if target_codes.empty?

    jobs = target_codes.map do |target_locale|
      TranslateContentJob.new(self.class.name, id, source_locale.to_s, target_locale)
    end

    ActiveJob.perform_all_later(jobs)
  end
end
