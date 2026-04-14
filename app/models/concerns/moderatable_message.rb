module ModeratableMessage
  extend ActiveSupport::Concern

  DEFAULT_PATTERNS = [
    /\b\+?\d[\d\s\-().]{7,}\b/,                              # E.164-ish phones
    /\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/i,                      # emails
    /@\w{3,}/,                                               # @handles
    %r{(?:wa|whatsapp|t|telegram|tg|viber)\.me/\S+}i
  ].freeze

  included do
    after_create_commit :enqueue_moderation
  end

  class_methods do
    def moderation_patterns
      DEFAULT_PATTERNS
    end
  end

  private

  def enqueue_moderation
    ModerateMessageJob.perform_later(id)
  end
end
