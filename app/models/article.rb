class Article < ApplicationRecord
  include Translatable

  belongs_to :team
  belongs_to :user

  translatable :title, type: :string
  translatable :body, type: :text

  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
