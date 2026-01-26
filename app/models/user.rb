class User < ApplicationRecord
  include Costable

  has_many :chats, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  def generate_magic_link_token
    signed_id(purpose: :magic_link, expires_in: 15.minutes)
  end

  # Recalculate total cost from all chats
  def recalculate_total_cost!
    update_column(:total_cost, chats.sum(:total_cost))
  end
end
