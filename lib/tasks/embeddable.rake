namespace :embeddings do
  desc "Rebuild embeddings for a model. Usage: bin/rails 'embeddings:rebuild[ModelName]'"
  task :rebuild, [ :model_name ] => :environment do |_t, args|
    model_name = args[:model_name]
    abort("Usage: bin/rails 'embeddings:rebuild[ModelName]'") if model_name.blank?

    model = model_name.constantize
    abort("#{model.name} does not include Embeddable") unless model.include?(Embeddable)

    conn = model.connection
    conn.execute("DELETE FROM #{model.embeddings_table}")

    total = model.count
    jobs = model.find_each.map { |record| EmbedRecordJob.new(model.name, record.id) }
    ActiveJob.perform_all_later(jobs)

    puts "Queued #{total} #{model.name} record(s) for re-embedding."
  end
end
