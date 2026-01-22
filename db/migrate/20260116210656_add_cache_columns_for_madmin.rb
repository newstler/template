class AddCacheColumnsForMadmin < ActiveRecord::Migration[8.2]
  def change
    # Add counter cache columns to models
    add_column :models, :chats_count, :integer, default: 0, null: false
    add_column :models, :total_cost, :decimal, precision: 12, scale: 6, default: 0, null: false

    # Add counter cache columns to chats
    add_column :chats, :messages_count, :integer, default: 0, null: false
    add_column :chats, :total_cost, :decimal, precision: 12, scale: 6, default: 0, null: false

    # Add counter cache column to users
    add_column :users, :total_cost, :decimal, precision: 12, scale: 6, default: 0, null: false
  end
end
