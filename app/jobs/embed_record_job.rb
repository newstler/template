class EmbedRecordJob < ApplicationJob
  queue_as :default

  def perform(class_name, id)
    klass = class_name.constantize
    record = klass.find_by(id: id)
    return unless record

    source = record.source_for_embedding
    return if source.blank?

    model = klass.embeddable_model_name
    return if model.blank?

    response = RubyLLM.embed(source, model: model)
    vector = response.vectors
    return if vector.blank?

    write_embedding(klass, record, vector, source)
    record_cost(record, model, response)
  end

  private

  def record_cost(record, model, response)
    AiCost.record!(
      cost_type: "embedding",
      model_id: model,
      input_tokens: response.input_tokens.to_i,
      team: record.try(:team),
      user: record.try(:user),
      trackable: record,
    )
  end

  def write_embedding(klass, record, vector, source)
    conn = klass.connection
    table = klass.embeddings_table
    source_hash = Digest::SHA256.hexdigest(source)
    metadata = record.metadata_for_embedding || {}
    vector_literal = "[#{vector.map(&:to_f).join(',')}]"

    columns = [ "id", "embedding", "source_hash" ] + metadata.keys.map(&:to_s)
    values = [
      conn.quote(record.id),
      conn.quote(vector_literal),
      conn.quote(source_hash)
    ] + metadata.values.map { |v| conn.quote(v) }

    # vec0 doesn't support INSERT OR REPLACE with string primary keys;
    # delete existing row then insert fresh (mirrors Searchable's
    # delete-then-insert pattern).
    conn.execute(
      klass.send(:sanitize_sql_array, [ "DELETE FROM #{table} WHERE id = ?", record.id ])
    )
    conn.execute(
      "INSERT INTO #{table} (#{columns.join(', ')}) VALUES (#{values.join(', ')})"
    )
  end
end
