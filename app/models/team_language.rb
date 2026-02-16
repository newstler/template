class TeamLanguage < ApplicationRecord
  belongs_to :team
  belongs_to :language

  validates :language_id, uniqueness: { scope: :team_id }

  scope :active, -> { where(active: true) }
end
