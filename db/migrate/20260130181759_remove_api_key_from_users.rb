class RemoveApiKeyFromUsers < ActiveRecord::Migration[8.2]
  def change
    remove_index :users, :api_key
    remove_column :users, :api_key, :string
  end
end
