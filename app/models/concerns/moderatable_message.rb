module ModeratableMessage
  extend ActiveSupport::Concern

  DEFAULT_PATTERNS = [
    /\b\+?\d[\d\s\-().]{7,}\b/,                              # E.164-ish phones
    /\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/i,                      # emails
    /@\w{3,}/,                                               # @handles
    %r{(?:wa|whatsapp|t|telegram|tg|viber)\.me/\S+}i
  ].freeze

  included do
    # Phase 1: synchronous regex gate. Fires before validation so the
    # flag is set on the record that actually gets persisted — the
    # broadcast, mailers, and view partials can then hide the message
    # from recipients immediately, with no race against the LLM job.
    before_validation :apply_regex_moderation

    # Phase 2: async LLM fallback. Only enqueued if the regex gate
    # didn't already flag the message.
    after_create_commit :enqueue_llm_moderation
  end

  class_methods do
    def moderation_patterns
      DEFAULT_PATTERNS
    end
  end

  private

  def apply_regex_moderation
    return unless Setting.conversation_moderation_enabled?
    return if content.blank?
    return if flagged_at.present?

    patterns = self.class.moderation_patterns
    match = patterns.find { |p| content.match?(p) }
    return unless match

    self.flagged_at = Time.current
    self.flag_reason = "regex:#{match.source[0, 50]}"
  end

  def enqueue_llm_moderation
    return unless Setting.conversation_moderation_enabled?
    return if flagged_at.present?
    ModerateMessageJob.perform_later(id)
  end
end
