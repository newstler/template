class AddRagSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :max_similarity_distance, :float, default: 0.75
    add_column :settings, :chunk_size, :integer, default: 400
    add_column :settings, :chunk_overlap, :integer, default: 40
    add_column :settings, :hybrid_pool_multiplier, :integer, default: 3
  end
end
