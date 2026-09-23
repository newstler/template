# Chat cost now lives in ruby_llm_usages. Chat spend was also mirrored into ai_costs; drop it so
# dashboards don't count it twice. Irreversible (restore a backup to roll back).
class DropAppCostCaches < ActiveRecord::Migration[8.1]
  def up
    remove_column :chats, :total_cost if column_exists?(:chats, :total_cost)
    remove_column :users, :total_cost if column_exists?(:users, :total_cost)
    remove_column :ruby_llm_models, :chats_count if column_exists?(:ruby_llm_models, :chats_count)
    remove_column :ruby_llm_models, :total_cost if column_exists?(:ruby_llm_models, :total_cost)
    remove_column :messages, :provider if column_exists?(:messages, :provider)
    execute "DELETE FROM ai_costs WHERE cost_type = 'chat'" if table_exists?(:ai_costs)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
