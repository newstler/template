class Chat < ApplicationRecord
  belongs_to :user
  acts_as_chat messages_foreign_key: :chat_id
end
