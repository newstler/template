class AddEnabledCurrenciesToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :enabled_currencies, :text
  end
end
