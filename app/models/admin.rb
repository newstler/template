class Admin < ApplicationRecord
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :locale, inclusion: { in: ->(_) { Language.enabled_codes } }, allow_nil: true

  before_validation :nilify_blank_locale

  def generate_magic_link_token
    signed_id(purpose: :magic_link, expires_in: 15.minutes)
  end

  private

  def nilify_blank_locale
    self.locale = nil if locale.blank?
  end
end
