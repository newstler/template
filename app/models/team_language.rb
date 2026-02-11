class TeamLanguage < ApplicationRecord
  belongs_to :team
  belongs_to :language

  scope :active, -> { where(active: true) }

  before_save :prevent_deactivating_english

  private

  def prevent_deactivating_english
    if language&.english? && active_changed? && !active?
      errors.add(:active, "cannot deactivate English")
      throw :abort
    end
  end
end
