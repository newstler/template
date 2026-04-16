class AddNotificationPreferencesToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :notification_preferences, :json, null: false, default: {}
  end
end
