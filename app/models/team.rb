class Team < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :chats, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  class << self
    def multi_tenant?
      Rails.configuration.x.multi_tenant
    end
  end

  def to_param
    slug
  end

  def total_chat_cost
    chats.sum(:total_cost)
  end

  private

  def generate_slug
    return if slug.present?

    base_slug = name&.parameterize
    self.slug = base_slug

    counter = 1
    while Team.exists?(slug: self.slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
