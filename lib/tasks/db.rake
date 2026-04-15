namespace :db do
  desc "Backfill chats.first_user_message_preview from each chat's first user message"
  task backfill_chat_previews: :environment do
    total = 0
    filled = 0

    Chat.where(first_user_message_preview: nil).find_each do |chat|
      total += 1
      first_user_message = chat.messages.where(role: "user").order(:created_at).first
      next unless first_user_message&.content.present?

      chat.update_columns(first_user_message_preview: first_user_message.content.to_s[0, 80])
      filled += 1
    end

    puts "[backfill_chat_previews] scanned=#{total} filled=#{filled}"
  end
end
