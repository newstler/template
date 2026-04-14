class AddCurrencyKeysToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :currencylayer_api_key, :string
    add_column :settings, :default_currency, :string, default: "USD"
    add_column :settings, :default_country_code, :string
  end
end
