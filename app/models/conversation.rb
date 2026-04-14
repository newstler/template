class Conversation < ApplicationRecord
  belongs_to :team
  belongs_to :subject, polymorphic: true, optional: true
end
