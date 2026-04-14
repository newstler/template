class AddCountryCodesToTeamsAndUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :teams, :country_code, :string
    add_column :users, :residence_country_code, :string
  end
end
