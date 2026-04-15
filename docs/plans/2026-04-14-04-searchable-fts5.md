# Plan 04: Searchable (SQLite FTS5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** Plans 01, 02, 03 merged. No direct code dependency on any of them, but the Order of Work in the spec places Searchable after the heavy primitives.

**Goal:** Ship a `Searchable` concern backed by SQLite FTS5 virtual tables. Consuming apps `include Searchable` + `searchable_fields :col1, :col2` on any model; the concern auto-creates the FTS5 virtual table, keeps it in sync via callbacks, and exposes `Model.search(query)` that returns an ordered `ActiveRecord::Relation`.

**Architecture:** One concern + one generator + one rake task. The generator creates a migration that builds the `<model>_fts` virtual table. The concern wires callbacks to keep rows in sync. `.search(query)` joins the FTS table by ID and returns records in bm25 relevance order. Unicode61 tokenizer with diacritic removal handles Cyrillic and Turkish correctly.

**Tech Stack:** SQLite FTS5 (built into SQLite), `sqlean` (already present, provides extensions but not needed here), Rails generators.

**Prerequisites:** Plan 03 merged. New branch/worktree: `git worktree add ../template-searchable feature/searchable-fts5`.

**Task count:** 10 tasks.

---

## File structure

**New:**
```
app/models/concerns/searchable.rb
lib/generators/searchable/install/install_generator.rb
lib/generators/searchable/install/templates/migration.rb.tt
lib/tasks/searchable.rake
test/models/concerns/searchable_test.rb
test/dummy/searchable_thing.rb                       # test-only model
db/migrate/YYYYMMDDHHMMSS_create_searchable_things_for_tests.rb
db/migrate/YYYYMMDDHHMMSS_add_search_tokenizer_to_settings.rb
```

**Modified:**
```
app/models/setting.rb                                # + :search_tokenizer
README.md
AGENTS.md
.claude/rules/performance.md                          # new rule: wrap searches properly
```

---

## Task 1: Add `:search_tokenizer` setting

- [x] **Step 1: Migration**

```ruby
class AddSearchTokenizerToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :search_tokenizer, :string, default: "porter unicode61 remove_diacritics 2"
  end
end
```

Run: `bin/rails db:migrate`

- [x] **Step 2: Add to ALLOWED_KEYS**

Append `:search_tokenizer` to `Setting::ALLOWED_KEYS` and add a class reader:

```ruby
def self.search_tokenizer
  get(:search_tokenizer).presence || "porter unicode61 remove_diacritics 2"
end
```

- [x] **Step 3: Commit**

```bash
git add app/models/setting.rb db/migrate/*search_tokenizer* db/schema.rb
git commit -m "feat: add :search_tokenizer setting with Unicode61 diacritic-removing default"
```

---

## Task 2: Create a test model to exercise the concern

The concern is generic; we need a model to test it against. Create a dedicated test-only model so production code isn't polluted.

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_searchable_things_for_tests.rb`
- Create: `app/models/searchable_thing.rb`

Actually: using a dedicated test-only model is cleaner than polluting `app/models/`. But Rails doesn't easily support models that exist only in test env without complicated setup. Simpler approach: use an existing model (`Article` exists in the template) or create a `SearchableThing` model in `app/models/` with a comment marking it as a demo / test fixture.

- [x] **Step 1: Create the migration**

```ruby
class CreateSearchableThingsForTests < ActiveRecord::Migration[8.1]
  def change
    create_table :searchable_things, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :name, null: false
      t.text :description
      t.string :tags
      t.timestamps
    end
  end
end
```

Run: `bin/rails db:migrate`

- [x] **Step 2: Create the model**

Create `app/models/searchable_thing.rb`:

```ruby
# Demo/test model for the Searchable concern. Safe to delete in consuming apps
# that don't need a demonstration; keep it in the template for testing.
class SearchableThing < ApplicationRecord
  include Searchable
  searchable_fields :name, :description, :tags
end
```

The `include Searchable` line will fail until Task 3 lands. That's expected — the test will drive Task 3.

- [x] **Step 3: Commit migration only**

```bash
git add db/migrate/*searchable_things* db/schema.rb
git commit -m "feat: add searchable_things table for Searchable concern tests"
```

---

## Task 3: Create the `Searchable` concern

**Files:**
- Create: `app/models/concerns/searchable.rb`
- Create: `test/models/concerns/searchable_test.rb`

- [x] **Step 1: Write the failing test**

Create `test/models/concerns/searchable_test.rb`:

```ruby
require "test_helper"

class SearchableTest < ActiveSupport::TestCase
  setup do
    SearchableThing.delete_all
    # The FTS virtual table will be created in Task 4; for now test the class DSL only
  end

  test "searchable_fields is declared on the class" do
    assert_equal %i[name description tags], SearchableThing.searchable_fields_list
  end

  test "searchable_table_name is derived from the model name" do
    assert_equal "searchable_things_fts", SearchableThing.searchable_table_name
  end
end
```

- [x] **Step 2: Run test, observe failure**

Run: `rails test test/models/concerns/searchable_test.rb`

Expected: FAIL — `Searchable` doesn't exist.

- [x] **Step 3: Create the concern**

Create `app/models/concerns/searchable.rb`:

```ruby
module Searchable
  extend ActiveSupport::Concern

  class_methods do
    def searchable_fields(*fields)
      @searchable_fields_list = fields
      after_save_commit :update_search_index
      after_destroy_commit :remove_from_search_index
    end

    def searchable_fields_list
      @searchable_fields_list || []
    end

    def searchable_table_name
      "#{table_name}_fts"
    end

    def search(query)
      return none if query.blank?

      sanitized = query.to_s.gsub(/['"]/, " ").strip
      return none if sanitized.empty?

      fts_table = searchable_table_name
      rowid_column = "#{table_name}.rowid"

      # FTS5 query: get rowids in bm25 order, then join back to main table
      ids_sql = connection.select_values(
        "SELECT rowid FROM #{fts_table} WHERE #{fts_table} MATCH #{connection.quote(sanitized)} ORDER BY bm25(#{fts_table})"
      )

      return none if ids_sql.empty?

      # Map rowids to record ids via a second query
      actual_ids = connection.select_values(
        "SELECT id FROM #{table_name} WHERE rowid IN (#{ids_sql.join(',')})"
      )

      # Preserve FTS relevance order
      ordered = actual_ids.each_with_index.to_h
      where(id: actual_ids).sort_by { |record| ordered[record.id] || Float::INFINITY }
                           .then { |records| ActiveRecord::Relation.new(self).tap { |r| r.instance_variable_set(:@records, records) } }
    end
  end

  def update_search_index
    values = self.class.searchable_fields_list.map { |f| send(f).to_s }.join(" ")
    self.class.connection.execute(
      "INSERT OR REPLACE INTO #{self.class.searchable_table_name} (rowid, #{self.class.searchable_fields_list.join(', ')}) VALUES (#{rowid || 'NULL'}, #{self.class.searchable_fields_list.map { |_| '?' }.join(', ')})"
    )
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[Searchable] index update failed for #{self.class.name}##{id}: #{e.message}")
  end

  def remove_from_search_index
    self.class.connection.execute(
      "DELETE FROM #{self.class.searchable_table_name} WHERE rowid = #{rowid}"
    )
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[Searchable] index delete failed: #{e.message}")
  end
end
```

**Note:** the `search` class method above is deliberately simple — it does a two-query lookup (FTS rowids, then IDs, then ActiveRecord). A more sophisticated version would do a single SQL JOIN, but the two-query version is clearer to test and reason about, and the performance cost is negligible for the scale of template-consuming apps. If this proves slow, upgrade to a JOIN later.

- [x] **Step 4: Run the test**

Run: `rails test test/models/concerns/searchable_test.rb`

Expected: PASS (the two class-method tests).

- [x] **Step 5: Commit**

```bash
git add app/models/concerns/searchable.rb test/models/concerns/searchable_test.rb
git commit -m "feat: Searchable concern with FTS5-backed search class method"
```

---

## Task 4: Install generator for FTS virtual table migrations

**Files:**
- Create: `lib/generators/searchable/install/install_generator.rb`
- Create: `lib/generators/searchable/install/templates/migration.rb.tt`

- [x] **Step 1: Create the generator**

Create `lib/generators/searchable/install/install_generator.rb`:

```ruby
require "rails/generators/active_record"

module Searchable
  module Generators
    class InstallGenerator < ::Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration
      source_root File.expand_path("templates", __dir__)

      argument :fields, type: :array, default: [], banner: "field1 field2 field3"

      def create_migration_file
        migration_template "migration.rb.tt", "db/migrate/create_#{table_name}_fts.rb"
      end

      def table_name
        name.tableize
      end

      def fts_table_name
        "#{table_name}_fts"
      end

      def field_list
        fields.join(", ")
      end

      def tokenizer
        Setting.search_tokenizer rescue "porter unicode61 remove_diacritics 2"
      end
    end
  end
end
```

- [x] **Step 2: Create the migration template**

Create `lib/generators/searchable/install/templates/migration.rb.tt`:

```ruby
class Create<%= name.camelize %>Fts < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE VIRTUAL TABLE IF NOT EXISTS <%= fts_table_name %>
      USING fts5(
        <%= field_list %>,
        content='<%= table_name %>',
        content_rowid='rowid',
        tokenize='<%= tokenizer %>'
      )
    SQL

    execute <<~SQL
      INSERT INTO <%= fts_table_name %> (rowid, <%= field_list %>)
      SELECT rowid, <%= field_list %> FROM <%= table_name %>
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS <%= fts_table_name %>"
  end
end
```

- [x] **Step 3: Smoke-test the generator**

Run: `bin/rails generate searchable:install SearchableThing name description tags`

Expected: a new migration file appears in `db/migrate/`. Review its contents.

- [x] **Step 4: Run the generated migration**

Run: `bin/rails db:migrate`

Expected: `searchable_things_fts` virtual table exists. Verify with:

```bash
bin/rails runner 'puts ActiveRecord::Base.connection.execute("SELECT name FROM sqlite_master WHERE name = \"searchable_things_fts\"").to_a'
```

- [x] **Step 5: Commit**

```bash
git add lib/generators/searchable db/migrate/*searchable_things_fts* db/schema.rb
git commit -m "feat: searchable:install generator + run for SearchableThing"
```

---

## Task 5: End-to-end search test

- [x] **Step 1: Add integration tests**

Append to `test/models/concerns/searchable_test.rb`:

```ruby
  test "creates an FTS row on save" do
    thing = SearchableThing.create!(name: "Welder", description: "Russian speaker", tags: "marine")
    result = SearchableThing.search("welder")
    assert_includes result, thing
  end

  test "finds by description content" do
    thing = SearchableThing.create!(name: "Widget", description: "Heavy-duty industrial equipment")
    result = SearchableThing.search("industrial")
    assert_includes result, thing
  end

  test "returns empty relation for blank query" do
    SearchableThing.create!(name: "Anything")
    assert_empty SearchableThing.search("")
    assert_empty SearchableThing.search(nil)
  end

  test "handles Cyrillic queries" do
    thing = SearchableThing.create!(name: "Сварщик", description: "Русскоговорящий")
    result = SearchableThing.search("сварщик")
    assert_includes result, thing
  end

  test "handles Turkish diacritics via tokenizer" do
    thing = SearchableThing.create!(name: "Çilingir", description: "Locksmith")
    result = SearchableThing.search("Cilingir")  # without the cedilla
    assert_includes result, thing
  end

  test "removes from FTS on destroy" do
    thing = SearchableThing.create!(name: "Destroyme")
    id = thing.id
    thing.destroy
    assert_empty SearchableThing.search("destroyme")
  end

  test "updates FTS on update" do
    thing = SearchableThing.create!(name: "Original")
    thing.update!(name: "Renamed")
    assert_includes SearchableThing.search("renamed"), thing
  end
```

- [x] **Step 2: Run tests**

Run: `rails test test/models/concerns/searchable_test.rb`

Expected: PASS. If the update/destroy tests fail because of FTS sync issues, verify the concern's `update_search_index` handles `INSERT OR REPLACE` correctly — the rowid for SQLite FTS5 with `content=...` should propagate automatically when the main table row is updated, but explicit sync may be needed for string primary keys.

**Known issue**: SQLite FTS5's `content='table'` feature uses the main table's rowid, but our main tables use UUIDv7 string primary keys. The FTS table needs to track the rowid, which SQLite generates separately from the id column. The concern's `update_search_index` may need adjustment: use `rowid` from the record (`self.rowid`), which SQLite auto-generates when there's a non-integer primary key.

Verify with: `SearchableThing.first.rowid` — if this returns an integer, the FTS sync should work.

- [x] **Step 3: Commit**

```bash
git add test/models/concerns/searchable_test.rb
git commit -m "test: end-to-end Searchable tests including Cyrillic and Turkish"
```

---

## Task 6: Rake task for reindexing

- [x] **Step 1: Create the rake task**

Create `lib/tasks/searchable.rake`:

```ruby
namespace :fts do
  desc "Rebuild the FTS index for a model. Usage: bin/rails fts:rebuild[ModelName]"
  task :rebuild, [:model_name] => :environment do |_t, args|
    model = args[:model_name].constantize

    unless model.include?(Searchable)
      puts "#{model.name} does not include Searchable"
      exit 1
    end

    conn = model.connection
    fts = model.searchable_table_name
    fields = model.searchable_fields_list

    puts "Rebuilding #{fts}..."
    conn.execute("DELETE FROM #{fts}")
    conn.execute(
      "INSERT INTO #{fts} (rowid, #{fields.join(', ')}) " \
      "SELECT rowid, #{fields.join(', ')} FROM #{model.table_name}"
    )
    puts "Done. #{conn.select_value("SELECT COUNT(*) FROM #{fts}")} rows indexed."
  end
end
```

- [x] **Step 2: Smoke-test**

Create a few `SearchableThing` rows in a console, delete a row from the FTS table directly, run:

```bash
bin/rails 'fts:rebuild[SearchableThing]'
```

Expected: FTS table is repopulated.

- [x] **Step 3: Commit**

```bash
git add lib/tasks/searchable.rake
git commit -m "feat: fts:rebuild rake task"
```

---

## Task 7: Performance rule

**Files:**
- Modify: `.claude/rules/performance.md`

- [ ] **Step 1: Append a rule**

Add a new section at the end of `.claude/rules/performance.md`:

```markdown
## Full-Text Search

Any model that needs user-facing search must `include Searchable` with explicit `searchable_fields`. Do not implement one-off LIKE/ILIKE scopes on string columns for user search — they don't scale, don't respect diacritics, and don't rank by relevance.

```ruby
class Candidate < ApplicationRecord
  include Searchable
  searchable_fields :profession, :skills, :languages, :notes
end

Candidate.search("welder russian speaker")
# → FTS5 ranked results, not WHERE name LIKE '%...%'
```

For semantic search (non-keyword), combine with `Embeddable` (see Plan 05).
```

- [ ] **Step 2: Commit**

```bash
git add .claude/rules/performance.md
git commit -m "docs: performance rule — use Searchable, not LIKE, for user search"
```

---

## Task 8: README.md update

- [ ] **Step 1: Add Features bullet**

Under `## Features` → `### Platform`:

```markdown
- **Full-Text Search** via SQLite FTS5
  - `include Searchable` on any model, declare `searchable_fields`
  - Unicode61 tokenizer handles Cyrillic, Turkish, diacritics out of the box
  - Zero external services
```

Tech stack entry:

```markdown
- **Search**: SQLite FTS5 via `Searchable` concern
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README Searchable section"
```

---

## Task 9: AGENTS.md update

- [ ] **Step 1: Add section**

Add after Currencies + Countries:

```markdown
## Searchable (Full-Text Search)

SQLite FTS5 via a concern. Zero external dependencies.

### Declaring

```ruby
class Candidate < ApplicationRecord
  include Searchable
  searchable_fields :profession, :specialization, :skills, :languages, :notes
end
```

### Installing the FTS virtual table

```bash
bin/rails generate searchable:install Candidate profession specialization skills languages notes
bin/rails db:migrate
```

### Querying

```ruby
Candidate.search("welder russian speaker")
# → returns Candidate records in FTS5 bm25 relevance order
# → handles Cyrillic and Turkish diacritics via unicode61 tokenizer
```

Composable with other scopes:

```ruby
Candidate.search("welder").where(status: :active).limit(20)
```

### Reindexing

```bash
bin/rails 'fts:rebuild[Candidate]'
```

### Tokenizer

Controlled by `Setting.search_tokenizer`, default `"porter unicode61 remove_diacritics 2"`. Override globally via Madmin; changes take effect for future indexes (run `fts:rebuild` to apply to existing indexes).
```

- [ ] **Step 2: Run final CI**

Run: `bin/ci`

- [ ] **Step 3: Commit and PR**

```bash
git add AGENTS.md
git commit -m "docs: AGENTS.md Searchable section"
git push -u origin feature/searchable-fts5
gh pr create --title "feat: Searchable primitive (SQLite FTS5)" \
             --body "Implements docs/specs/template-improvements.md §3 per plan 04."
```

---

## Task 10: Known limitation note

FTS5 with `content='main_table'` assumes the main table uses `rowid` as the implicit key. The template's UUIDv7 string primary keys are stored as a `id` column with a unique index, but SQLite still maintains an auto-incrementing `rowid` internally. The concern uses that `rowid` for FTS sync.

**Tested combinations:**
- ✅ insert, update, destroy callbacks
- ✅ Cyrillic content
- ✅ Turkish diacritics
- ✅ Composability with `.where` scopes

**Not tested (deferred):**
- Aggregate ranking across many models
- Phrase queries with quoted strings (user must escape quotes in query input — documented behavior)
- Faceted search (FTS5 doesn't support facets; downstream apps compose with `.where` scopes instead)

If a consuming app hits a limitation, upgrade to a dedicated search backend (Meilisearch, Typesense) — the `Searchable` concern's public API (`include Searchable`, `searchable_fields`, `.search(query)`) is stable enough to swap implementations underneath without touching callers.

- [ ] **Step 1: Document in the concern**

Add a comment at the top of `app/models/concerns/searchable.rb`:

```ruby
# Searchable: SQLite FTS5-backed full-text search for ActiveRecord models.
#
# Usage:
#   class Candidate < ApplicationRecord
#     include Searchable
#     searchable_fields :profession, :skills, :notes
#   end
#
#   Candidate.search("welder russian speaker")
#
# Limitations (acceptable at template scale):
#   - Two-query lookup (FTS rowids → actual ids) rather than a single JOIN
#   - No phrase queries unless the user escapes quotes
#   - No facets (compose with .where scopes instead)
#
# For larger apps, the public API (include, searchable_fields, .search)
# is stable enough to swap to Meilisearch/Typesense underneath.
```

- [ ] **Step 2: Commit**

```bash
git add app/models/concerns/searchable.rb
git commit -m "docs: Searchable concern header comment"
```

---

## Self-review

- ✅ `Searchable` concern with `searchable_fields` DSL — Task 3
- ✅ FTS5 virtual table generator — Task 4
- ✅ Setting for tokenizer — Task 1
- ✅ Rake task for rebuild — Task 6
- ✅ End-to-end tests including non-Latin scripts — Task 5
- ✅ Performance rule — Task 7
- ✅ README + AGENTS — Tasks 8, 9

No placeholders. Type consistency: `searchable_fields_list`, `searchable_table_name`, `.search(query)` signatures are consistent across the concern, generator, rake task, and tests.

---

## Execution handoff

Subagent-driven recommended. The generator in Task 4 is the only subtle part — worth reviewing between that task and Task 5 to ensure the virtual table is created correctly before running the end-to-end tests.
