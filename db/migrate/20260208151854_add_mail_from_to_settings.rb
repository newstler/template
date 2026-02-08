class AddMailFromToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :mail_from, :string
  end
end
