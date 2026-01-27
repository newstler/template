---
description: Database migration conventions
globs: ["db/migrate/**/*.rb"]
---

# Migration Standards

## UUIDv7 Primary Keys

All tables use UUIDv7 string primary keys with database-level default:

```ruby
class CreateCards < ActiveRecord::Migration[8.0]
  def change
    create_table :cards, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :title, null: false
      t.timestamps
    end
  end
end
```

**Key points:**
- `id: { type: :string, default: -> { "uuid7()" } }` - String PK with SQLite-generated UUIDv7
- `force: true` - Drop table if exists (optional, useful in dev)
- No model callback needed - database handles ID generation

## Foreign Keys

Reference other tables with string type and foreign key constraints:

```ruby
create_table :comments, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
  t.references :card, null: false, foreign_key: true, type: :string
  t.references :author, null: false, foreign_key: { to_table: :users }, type: :string
  t.text :body, null: false
  t.timestamps
end
```

## Constraints Over Validations

Prefer database-level constraints:

```ruby
# ✅ GOOD: Database constraint
t.string :email, null: false
add_index :users, :email, unique: true

# ❌ AVOID: Model-only validation (use both if needed)
validates :email, presence: true, uniqueness: true
```

## Common Patterns

### State Records (not boolean columns)

```ruby
# ✅ GOOD: State as separate table
create_table :closures, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
  t.references :closeable, polymorphic: true, null: false, type: :string
  t.references :closed_by, null: false, foreign_key: { to_table: :users }, type: :string
  t.timestamps
end

# ❌ AVOID: Boolean column
add_column :cards, :closed, :boolean, default: false
```

### Timestamps

Always include timestamps:

```ruby
create_table :cards, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
  # columns...
  t.timestamps  # adds created_at and updated_at
end
```

### Indexes

Add indexes for:
- Foreign keys (automatic with `references`)
- Columns used in WHERE clauses
- Columns used in ORDER BY
- Unique constraints

```ruby
add_index :cards, :board_id
add_index :cards, [:board_id, :created_at]
add_index :cards, :title, where: "deleted_at IS NULL"
```

## Reversible Migrations

Make migrations reversible when possible:

```ruby
class AddDescriptionToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :description, :text  # Reversible
  end
end

# For complex changes, use up/down
class ComplexMigration < ActiveRecord::Migration[8.0]
  def up
    # Forward migration
  end

  def down
    # Rollback
  end
end
```

## Data Migrations

Separate data migrations from schema migrations:

```ruby
# db/migrate/20240101_add_status_to_cards.rb
class AddStatusToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :status, :string, default: "draft"
  end
end

# lib/tasks/data_migrations.rake
namespace :data do
  desc "Backfill card statuses"
  task backfill_card_statuses: :environment do
    Card.where(status: nil).update_all(status: "draft")
  end
end
```

## SQLite Specifics

SQLite has some limitations:

```ruby
# ❌ Cannot change column in SQLite easily
change_column :cards, :title, :text

# ✅ Create new table and migrate data
class ChangeCardTitleToText < ActiveRecord::Migration[8.0]
  def up
    rename_table :cards, :cards_old
    create_table :cards, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.text :title  # Changed from string
      t.timestamps
    end
    execute "INSERT INTO cards SELECT * FROM cards_old"
    drop_table :cards_old
  end
end
```

## Running Migrations

```bash
rails db:migrate              # Run pending migrations
rails db:migrate:status       # Show migration status
rails db:rollback             # Rollback last migration
rails db:rollback STEP=3      # Rollback 3 migrations
rails db:migrate VERSION=0    # Rollback all
```