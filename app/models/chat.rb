class Chat < ApplicationRecord
  belongs_to :user
  belongs_to :team, optional: true
  acts_as_chat

  scope :chronologically, -> { order(updated_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }
end
