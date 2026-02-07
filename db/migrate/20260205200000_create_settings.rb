class CreateSettings < ActiveRecord::Migration[8.2]
  def change
    create_table :settings, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :openai_api_key
      t.string :anthropic_api_key
      t.string :stripe_secret_key
      t.string :stripe_publishable_key
      t.string :stripe_webhook_secret
      t.string :smtp_address
      t.string :smtp_username
      t.string :smtp_password
      t.string :litestream_replica_bucket
      t.string :litestream_replica_key_id
      t.string :litestream_replica_access_key
      t.timestamps
    end
  end
end
