# Noticed install migration, patched for UUIDv7 string primary keys.
# Originally derived from `rails noticed:install:migrations` (noticed v2).
class CreateNoticedTables < ActiveRecord::Migration[8.1]
  def change
    create_table :noticed_events, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :type
      t.references :record, polymorphic: true, type: :string
      t.json :params

      t.integer :notifications_count
      t.timestamps
    end

    create_table :noticed_notifications, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :type
      t.references :event, null: false, foreign_key: { to_table: :noticed_events }, type: :string
      t.references :recipient, polymorphic: true, null: false, type: :string

      t.datetime :read_at
      t.datetime :seen_at

      t.timestamps
    end
  end
end
