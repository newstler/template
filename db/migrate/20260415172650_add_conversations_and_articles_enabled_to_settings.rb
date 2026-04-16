class AddConversationsAndArticlesEnabledToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :conversations_enabled, :boolean, default: true, null: false
    add_column :settings, :articles_enabled, :boolean, default: true, null: false
  end
end
