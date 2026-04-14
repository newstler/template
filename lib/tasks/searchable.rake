namespace :fts do
  desc "Rebuild the FTS index for a model. Usage: bin/rails 'fts:rebuild[ModelName]'"
  task :rebuild, [ :model_name ] => :environment do |_t, args|
    model_name = args[:model_name]

    if model_name.blank?
      puts "Usage: bin/rails 'fts:rebuild[ModelName]'"
      exit 1
    end

    model = model_name.constantize

    unless model.include?(Searchable)
      puts "#{model.name} does not include Searchable"
      exit 1
    end

    conn = model.connection
    fts = model.searchable_table_name
    fields = model.searchable_fields_list
    columns = ([ "id" ] + fields.map(&:to_s)).join(", ")

    puts "Rebuilding #{fts}..."
    conn.execute("DELETE FROM #{fts}")
    conn.execute(
      "INSERT INTO #{fts} (#{columns}) " \
      "SELECT #{columns} FROM #{model.table_name}"
    )
    count = conn.select_value("SELECT COUNT(*) FROM #{fts}")
    puts "Done. #{count} rows indexed."
  end
end
