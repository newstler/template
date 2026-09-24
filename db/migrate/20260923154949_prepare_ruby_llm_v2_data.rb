# Shapes RubyLLM 1.x data the way ruby_llm's 2.0 upgrade migrations expect.
# Runs before them; irreversible (restore a backup to roll back).
class PrepareRubyLlmV2Data < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:models) && column_exists?(:messages, :model_id)

    # Fail before touching anything: without a registry row the 2.0 upgrade can't attribute messages.
    if select_value("SELECT COUNT(*) FROM models").to_i.zero? && select_value("SELECT COUNT(*) FROM messages").to_i.positive?
      raise "The models table is empty. Run `bin/rails ruby_llm:load_models` on the 1.x release, then migrate again."
    end

    # The 2.0 backfill carries historical cost from messages.total_cost only.
    rename_column :messages, :cost, :total_cost if column_exists?(:messages, :cost)
    add_column :messages, :provider, :string unless column_exists?(:messages, :provider)

    # messages.cost defaulted to 0.0; the backfill treats any non-NULL cost as a billed attempt, so a
    # zero on a user/tool message would become an empty usage row.
    execute "UPDATE messages SET total_cost = NULL WHERE total_cost = 0 AND role <> 'assistant'"

    remove_foreign_key :messages, :models if foreign_key_exists?(:messages, :models)
    remove_index :messages, :model_id if index_exists?(:messages, :model_id)

    # messages.model_id held models.id; the 2.0 backfill reads a string column as the model name.
    execute <<~SQL
      UPDATE messages
      SET provider = (SELECT provider FROM models WHERE models.id = messages.model_id),
          model_id = (SELECT model_id FROM models WHERE models.id = messages.model_id)
      WHERE model_id IN (SELECT id FROM models)
    SQL

    # The 2.0 upgrade refuses assistant messages that resolve no model: give model-less chats the default.
    if (default_model_id = default_model_row_id)
      execute "UPDATE chats SET model_id = #{quote(default_model_id)} WHERE model_id IS NULL"
    end

    execute <<~SQL
      UPDATE messages
      SET provider = (SELECT m.provider FROM chats c JOIN models m ON m.id = c.model_id WHERE c.id = messages.chat_id),
          model_id = (SELECT m.model_id FROM chats c JOIN models m ON m.id = c.model_id WHERE c.id = messages.chat_id)
      WHERE model_id IS NULL AND role = 'assistant'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Setting.default_model if it names a registry row, else the chats' most-used model, else any model.
  def default_model_row_id
    configured_default_row_id ||
      select_value("SELECT model_id FROM chats WHERE model_id IS NOT NULL GROUP BY model_id ORDER BY COUNT(*) DESC, model_id LIMIT 1") ||
      select_value("SELECT id FROM models ORDER BY provider, model_id LIMIT 1")
  end

  def configured_default_row_id
    return unless table_exists?(:settings) && column_exists?(:settings, :default_model)

    name = select_value("SELECT default_model FROM settings WHERE default_model IS NOT NULL LIMIT 1")
    select_value("SELECT id FROM models WHERE model_id = #{quote(name)} ORDER BY provider LIMIT 1") if name.present?
  end
end
