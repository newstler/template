class AddCostToMessages < ActiveRecord::Migration[8.2]
  def change
    add_column :messages, :cost, :decimal, precision: 10, scale: 6, default: 0.0
  end
end
