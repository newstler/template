class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  def generate_magic_link_token
    signed_id(purpose: :magic_link, expires_in: 15.minutes)
  end
end
