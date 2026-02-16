class AddLocaleToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :locale, :string
  end
end
