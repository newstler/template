namespace :counter_cache do
  desc "Populate all counter cache columns"
  task populate: :environment do
    puts "Populating counter caches..."

    # Update chats messages_count and total_cost
    puts "Updating chats..."
    Chat.find_each do |chat|
      chat.update_columns(
        messages_count: chat.messages.count,
        total_cost: chat.messages.sum(:cost)
      )
    end

    # Update models chats_count and total_cost
    puts "Updating models..."
    Model.find_each do |model|
      model.update_columns(
        chats_count: model.chats.count,
        total_cost: model.chats.sum(:total_cost)
      )
    end

    # Update users total_cost
    puts "Updating users..."
    User.find_each do |user|
      user.update_column(:total_cost, user.chats.sum(:total_cost))
    end

    puts "Done!"
  end
end
