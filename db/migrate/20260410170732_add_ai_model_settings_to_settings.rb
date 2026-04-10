class AddAiModelSettingsToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :default_model, :string
    add_column :settings, :translation_model, :string
  end
end
