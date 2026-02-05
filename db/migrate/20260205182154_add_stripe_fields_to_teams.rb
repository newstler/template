class AddStripeFieldsToTeams < ActiveRecord::Migration[8.2]
  def change
    add_column :teams, :stripe_customer_id, :string
    add_column :teams, :stripe_subscription_id, :string
    add_column :teams, :subscription_status, :string
    add_column :teams, :current_period_ends_at, :datetime

    add_index :teams, :stripe_customer_id, unique: true
    add_index :teams, :stripe_subscription_id, unique: true
  end
end
