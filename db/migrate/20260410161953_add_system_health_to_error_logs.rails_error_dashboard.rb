# frozen_string_literal: true

class AddSystemHealthToErrorLogs < ActiveRecord::Migration[7.0]
  def up
    return if column_exists?(:rails_error_dashboard_error_logs, :system_health)
    add_column :rails_error_dashboard_error_logs, :system_health, :text
  end

  def down
    remove_column :rails_error_dashboard_error_logs, :system_health if column_exists?(:rails_error_dashboard_error_logs, :system_health)
  end
end
