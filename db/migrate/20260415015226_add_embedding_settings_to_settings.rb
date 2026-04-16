class AddEmbeddingSettingsToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :embedding_model, :string, default: "text-embedding-3-small"
    add_column :settings, :rrf_k, :integer, default: 60
  end
end
