namespace :counter_cache do
  desc "Populate all counter cache columns"
  task populate: :environment do
    puts "Updating chats..."
    Chat.find_each do |chat|
      chat.update_columns(messages_count: chat.messages.count)
    end

    puts "Done!"
  end
end
