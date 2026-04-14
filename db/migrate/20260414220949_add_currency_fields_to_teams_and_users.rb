class AddCurrencyFieldsToTeamsAndUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :teams, :default_currency, :string, null: false, default: "USD"
    add_column :users, :preferred_currency, :string
  end
end
