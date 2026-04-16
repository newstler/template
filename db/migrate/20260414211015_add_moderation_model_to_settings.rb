class AddModerationModelToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :moderation_model, :string
  end
end
