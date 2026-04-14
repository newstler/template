class CreateSearchableThingsFts < ActiveRecord::Migration[8.2]
  # Uses create_virtual_table so Rails' schema dumper can round-trip the FTS5
  # definition into schema.rb on db:migrate.
  def up
    create_virtual_table :searchable_things_fts, :fts5, [
      "id UNINDEXED",
      "name", "description", "tags",
      "tokenize='porter unicode61 remove_diacritics 2'"
    ]

    execute(
      "INSERT INTO searchable_things_fts (id, name, description, tags) " \
      "SELECT id, name, description, tags FROM searchable_things"
    )
  end

  def down
    drop_virtual_table :searchable_things_fts, :fts5, []
  end
end
