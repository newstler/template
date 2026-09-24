# Chat cost now lives in ruby_llm_usages. Chat spend was also mirrored into ai_costs; drop the rows whose
# message still exists (its usage row carries the same cost) so dashboards don't count it twice. Rows for
# already-deleted chats have no usage row, so they stay. Irreversible (restore a backup to roll back).
class DropAppCostCaches < ActiveRecord::Migration[8.1]
  def up
    remove_column :chats, :total_cost if column_exists?(:chats, :total_cost)
    remove_column :users, :total_cost if column_exists?(:users, :total_cost)
    remove_column :ruby_llm_models, :chats_count if column_exists?(:ruby_llm_models, :chats_count)
    remove_column :ruby_llm_models, :total_cost if column_exists?(:ruby_llm_models, :total_cost)
    remove_column :messages, :provider if column_exists?(:messages, :provider)
    return unless table_exists?(:ai_costs)

    execute <<~SQL
      DELETE FROM ai_costs
      WHERE cost_type = 'chat' AND trackable_type = 'Message' AND trackable_id IN (SELECT id FROM messages)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
