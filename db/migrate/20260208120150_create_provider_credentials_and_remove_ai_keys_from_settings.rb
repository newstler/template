class CreateProviderCredentialsAndRemoveAiKeysFromSettings < ActiveRecord::Migration[8.2]
  def change
    create_table :provider_credentials, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :provider, null: false
      t.string :key, null: false
      t.string :value
      t.timestamps
    end

    add_index :provider_credentials, [ :provider, :key ], unique: true

    remove_column :settings, :openai_api_key, :string
    remove_column :settings, :anthropic_api_key, :string
  end
end
