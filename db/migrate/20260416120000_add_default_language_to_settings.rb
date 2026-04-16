class AddDefaultLanguageToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :default_language, :string, default: "en"
  end
end
