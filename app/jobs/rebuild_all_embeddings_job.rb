class RebuildAllEmbeddingsJob < ApplicationJob
  queue_as :default

  EMBEDDABLE_MODELS = %w[Article SearchableThing Chunk].freeze

  def perform
    model_record = Model.find_by(model_id: Setting.embedding_model)
    dimensions = model_record&.max_output_tokens
    return Rails.logger.error("[RebuildAllEmbeddingsJob] Cannot determine dimensions for #{Setting.embedding_model}") unless dimensions

    EMBEDDABLE_MODELS.each do |class_name|
      klass = class_name.safe_constantize
      next unless klass&.include?(Embeddable)

      recreate_vec0_table(klass, dimensions)
      enqueue_embeddings(klass)
    end
  end

  private

  def recreate_vec0_table(klass, dimensions)
    conn = klass.connection
    table = klass.embeddings_table
    distance = klass.embeddable_distance

    conn.execute("DROP TABLE IF EXISTS #{table}")

    columns = [ "id text primary key", "embedding float[#{dimensions}] distance_metric=#{distance}", "source_hash text" ]

    metadata_sample = klass.first
    if metadata_sample
      klass.embeddable_metadata_for(metadata_sample).each_key do |key|
        columns.insert(-2, "#{key} text partition key")
      end
    end

    col_sql = columns.join(", ")
    conn.execute("CREATE VIRTUAL TABLE #{table} USING vec0(#{col_sql})")

    Rails.logger.info("[RebuildAllEmbeddingsJob] Recreated #{table} with #{dimensions} dimensions")
  end

  def enqueue_embeddings(klass)
    total = klass.count
    return if total.zero?

    jobs = klass.find_each.map { |record| EmbedRecordJob.new(klass.name, record.id) }
    ActiveJob.perform_all_later(jobs)

    Rails.logger.info("[RebuildAllEmbeddingsJob] Queued #{total} #{klass.name} records for re-embedding")
  end
end
