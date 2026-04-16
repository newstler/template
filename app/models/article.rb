class Article < ApplicationRecord
  include Translatable
  include Searchable
  include Embeddable
  include HybridSearchable

  belongs_to :team
  belongs_to :user

  translatable :title, type: :string
  translatable :body, type: :text

  searchable_fields :title

  embeddable_source ->(record) { record.embedding_source_text }
  embeddable_model  -> { Setting.embedding_model }
  embeddable_distance :cosine

  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # Build embedding source from the English content plus all translations.
  # This enables cross-language vector search.
  def embedding_source_text
    parts = [ title.to_s, body.to_s ]

    locales = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
      .where(translatable_type: self.class.name, translatable_id: id)
      .distinct
      .pluck(:locale)

    locales.each do |locale|
      Mobility.with_locale(locale) do
        parts << title.to_s << body.to_s
      end
    end

    parts.reject(&:blank?).join("\n\n")
  end
end
