module Translatable
  extend ActiveSupport::Concern

  included do
    extend Mobility

    class_attribute :translatable_attributes, default: []

    attr_accessor :skip_translation_callbacks

    after_commit :queue_translations, on: [ :create, :update ]
  end

  class_methods do
    # Declare translatable attributes and set up Mobility.
    # Each attribute needs an explicit type (:string or :text).
    #
    #   translatable :title, type: :string
    #   translatable :body, type: :text
    #
    def translatable(attribute, type: :string)
      self.translatable_attributes = translatable_attributes + [ attribute.to_s ]
      translates attribute, backend: :key_value, type: type
    end
  end

  def source_locale
    Current.user&.effective_locale || :en
  end

  private

  def queue_translations
    return if skip_translation_callbacks
    return unless translatable_attributes_changed?
    return unless respond_to?(:team) && team.present?

    target_codes = team.translation_target_codes(exclude: source_locale.to_s)
    return if target_codes.empty?

    jobs = target_codes.map do |target_locale|
      TranslateContentJob.new(self.class.name, id, source_locale.to_s, target_locale)
    end

    ActiveJob.perform_all_later(jobs)
  end

  def translatable_attributes_changed?
    return true if previously_new_record?

    (previous_changes.keys & self.class.translatable_attributes).any?
  end
end
