module TranslatableMessage
  extend ActiveSupport::Concern

  included do
    after_create_commit :enqueue_translation
  end

  private

  def enqueue_translation
    TranslateMessageJob.perform_later(id)
  end
end
