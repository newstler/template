class AddCancelAtPeriodEndToTeams < ActiveRecord::Migration[8.2]
  def change
    add_column :teams, :cancel_at_period_end, :boolean, default: false, null: false
  end
end
