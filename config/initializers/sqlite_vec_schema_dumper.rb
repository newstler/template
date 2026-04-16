# vec0 virtual tables create internal "shadow" tables to hold vector
# chunks, rowid maps, and metadata. These are rebuilt automatically by
# the vec0 extension whenever the virtual table is created, so the
# schema dumper should not emit them. Some of them have columns
# without a type (e.g. +rowid PRIMARY KEY+) which Rails 8's schema
# statements can't parse — dumping them crashes +db:schema:dump+.
Rails.application.config.after_initialize do
  ActiveRecord::SchemaDumper.ignore_tables |= [ SqliteVec::SHADOW_TABLE_REGEX ]
end
