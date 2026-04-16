class AddLocaleToAdmins < ActiveRecord::Migration[8.2]
  def change
    add_column :admins, :locale, :string
  end
end
