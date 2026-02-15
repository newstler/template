class TeamLanguage < ApplicationRecord
  belongs_to :team
  belongs_to :language

  scope :active, -> { where(active: true) }
end
