class AddApiKeyToTeams < ActiveRecord::Migration[8.2]
  def change
    add_column :teams, :api_key, :string
    add_index :teams, :api_key, unique: true
  end
end
