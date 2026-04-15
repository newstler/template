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

  embeddable_source ->(record) { record.body.to_s }
  embeddable_model  -> { Setting.embedding_model }
  embeddable_distance :cosine

  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
