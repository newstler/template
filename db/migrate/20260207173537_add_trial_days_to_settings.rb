class AddTrialDaysToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :trial_days, :integer, default: 30
  end
end
