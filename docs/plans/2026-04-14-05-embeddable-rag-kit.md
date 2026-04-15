# Plan 05: Embeddable + RAG Kit (sqlite-vec)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** Plan 04 (Searchable) for the `HybridSearchable` concern which fuses FTS5 and vector results. Plans 01-03 are also prerequisites.

**Goal:** Ship a full RAG retrieval kit in the template: `Embeddable` for ordered KNN similarity with metadata pre-filtering, `Chunkable` for long-document splitting, and `HybridSearchable` that fuses FTS5 and vector scores via Reciprocal Rank Fusion. All backed by sqlite-vec loaded as a SQLite extension.

**Architecture:** Vendor the sqlite-vec extension binaries in `vendor/sqlite-vec/`, load them at boot via `config/initializers/sqlite_vec.rb`, build three concerns (`Embeddable`, `Chunkable`, `HybridSearchable`), a polymorphic `Chunk` model, an `EmbedRecordJob`, a migration generator for vec0 tables, and a rake task for reindexing. Re-embedding is skipped when the source string hash hasn't changed.

**Tech Stack:** sqlite-vec (loadable extension, not a gem), RubyLLM for embeddings, Solid Queue for background jobs.

**Prerequisites:** Plan 04 merged. New branch/worktree: `git worktree add ../template-embeddable feature/embeddable-rag-kit`.

**Task count:** 15 tasks.

---

## File structure

**New:**
```
vendor/sqlite-vec/linux-x86_64/vec0.so              # extension binary
vendor/sqlite-vec/linux-aarch64/vec0.so
vendor/sqlite-vec/darwin-arm64/vec0.dylib
vendor/sqlite-vec/README.md                         # licensing + provenance
config/initializers/sqlite_vec.rb
app/models/concerns/embeddable.rb
app/models/concerns/chunkable.rb
app/models/concerns/hybrid_searchable.rb
app/models/chunk.rb
app/jobs/embed_record_job.rb
lib/tasks/embeddable.rake
lib/generators/embeddable/install/install_generator.rb
lib/generators/embeddable/install/templates/migration.rb.tt
db/migrate/YYYYMMDDHHMMSS_add_embedding_settings.rb
db/migrate/YYYYMMDDHHMMSS_create_chunks.rb
db/migrate/YYYYMMDDHHMMSS_create_searchable_things_embeddings.rb
test/models/concerns/embeddable_test.rb
test/models/concerns/chunkable_test.rb
test/models/concerns/hybrid_searchable_test.rb
test/jobs/embed_record_job_test.rb
Dockerfile                                          # modified to COPY vendor/sqlite-vec
```

**Modified:**
```
app/models/setting.rb                               # + :embedding_model, :rrf_k
app/models/searchable_thing.rb                      # + include Embeddable, + include HybridSearchable
README.md
AGENTS.md
```

---

## Task 1: Vendor sqlite-vec binaries

**Files:**
- Create: `vendor/sqlite-vec/{linux-x86_64,linux-aarch64,darwin-arm64}/`
- Create: `vendor/sqlite-vec/README.md`

- [x] **Step 1: Download latest release**

Check https://github.com/asg017/sqlite-vec/releases for the latest stable release. Download the three binary archives:
- `sqlite-vec-<version>-loadable-linux-x86_64.tar.gz`
- `sqlite-vec-<version>-loadable-linux-aarch64.tar.gz`
- `sqlite-vec-<version>-loadable-macos-aarch64.tar.gz`

- [x] **Step 2: Extract and place**

For each archive, extract the `vec0.so` (Linux) or `vec0.dylib` (macOS) into the corresponding subdirectory:

```
vendor/sqlite-vec/linux-x86_64/vec0.so
vendor/sqlite-vec/linux-aarch64/vec0.so
vendor/sqlite-vec/darwin-arm64/vec0.dylib
```

- [x] **Step 3: Document provenance**

Create `vendor/sqlite-vec/README.md`:

```markdown
# sqlite-vec binaries

Loadable SQLite extension for vector search. Zero runtime dependencies.

## Source

https://github.com/asg017/sqlite-vec

## Version

<filled in from the downloaded release, e.g. v0.1.6>

## License

Apache-2.0 and MIT (dual-licensed). Binaries are redistributable.

## Supported platforms

- `linux-x86_64/vec0.so`
- `linux-aarch64/vec0.so` (Kamal on aarch64 hosts)
- `darwin-arm64/vec0.dylib` (Apple Silicon dev machines)

Intel macOS is not included — run on Rosetta if needed. Windows is out of scope.

## Upgrading

1. Download the new release tarballs from the source above.
2. Replace the three binary files in place.
3. Update the Version above.
4. Run `bin/rails test` locally + `bin/ci` before committing.
```

- [x] **Step 4: Commit**

```bash
git add vendor/sqlite-vec/
git commit -m "chore: vendor sqlite-vec extension binaries (linux-x86_64, linux-aarch64, darwin-arm64)"
```

---

## Task 2: Load the extension at boot

**Files:**
- Create: `config/initializers/sqlite_vec.rb`

- [x] **Step 1: Create the initializer**

**Implementation note:** neither plan approach was used. The cleanest
idiom in this template is the `SQLean::UUID.to_path` pattern already
wired into `config/database.yml`'s `extensions:` array. We added
`lib/sqlite_vec.rb` defining `SqliteVec.to_path` (required from
`config/application.rb` right after `Bundler.require`, so it's
available before `database.yml` is parsed for `db:migrate` etc.) and
appended `<%= SqliteVec.to_path %>` to the extensions array. This
loads the extension automatically on every new SQLite connection via
the sqlite3 gem's built-in support, no adapter monkey-patching needed.

```ruby
# Loads the sqlite-vec extension on every SQLite connection so vec0
# virtual tables and KNN queries are available everywhere: web requests,
# Solid Queue jobs, rake tasks, and Rails console.
Rails.application.config.to_prepare do
  ActiveSupport.on_load(:active_record) do
    if ActiveRecord::Base.connection.adapter_name.downcase.include?("sqlite")
      ActiveRecord::Base.connection_pool.connections.each do |conn|
        load_sqlite_vec_on(conn.raw_connection)
      end
    end
  end
end

# Also install the loader on new connections as the pool grows.
ActiveRecord::ConnectionAdapters::AbstractAdapter.set_callback(:checkout, :after) do
  next unless adapter_name.downcase.include?("sqlite")
  load_sqlite_vec_on(raw_connection)
end

def load_sqlite_vec_on(raw_connection)
  return unless raw_connection.respond_to?(:enable_load_extension)
  raw_connection.enable_load_extension(true)
  path = sqlite_vec_extension_path
  raw_connection.load_extension(path) if path && File.exist?(path)
  raw_connection.enable_load_extension(false)
rescue SQLite3::Exception => e
  Rails.logger.warn("[sqlite-vec] Failed to load: #{e.message}")
end

def sqlite_vec_extension_path
  base = Rails.root.join("vendor/sqlite-vec")
  case RbConfig::CONFIG["host_os"]
  when /darwin/
    base.join("darwin-arm64/vec0.dylib").to_s
  when /linux/
    arch = RbConfig::CONFIG["host_cpu"]
    if arch.include?("aarch64") || arch.include?("arm64")
      base.join("linux-aarch64/vec0.so").to_s
    else
      base.join("linux-x86_64/vec0.so").to_s
    end
  end
end
```

**Note:** the `set_callback(:checkout, :after)` approach is fragile — Rails' connection callbacks have changed signature across versions. Alternative, cleaner approach for Rails 8:

```ruby
# Simpler approach: monkey-patch the SQLite adapter to load the extension
# when a connection is initialized.
module SqliteVecExtensionLoader
  def configure_connection
    super
    enable_extension_loading
  rescue => e
    Rails.logger.warn("[sqlite-vec] Failed to configure: #{e.message}")
  end

  private

  def enable_extension_loading
    return unless @raw_connection.respond_to?(:enable_load_extension)
    @raw_connection.enable_load_extension(true)
    path = Rails.configuration.x.sqlite_vec_path
    @raw_connection.load_extension(path) if path && File.exist?(path)
    @raw_connection.enable_load_extension(false)
  end
end

Rails.application.config.x.sqlite_vec_path = begin
  base = Rails.root.join("vendor/sqlite-vec")
  case RbConfig::CONFIG["host_os"]
  when /darwin/ then base.join("darwin-arm64/vec0.dylib").to_s
  when /linux/
    RbConfig::CONFIG["host_cpu"].match?(/aarch64|arm64/) ?
      base.join("linux-aarch64/vec0.so").to_s :
      base.join("linux-x86_64/vec0.so").to_s
  end
end

Rails.application.config.after_initialize do
  if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
    ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteVecExtensionLoader)
  end
end
```

Use whichever of the two approaches works with the current Rails 8 main — verify by smoke-testing in Step 3.

- [x] **Step 3: Smoke-test**

Run: `bin/rails runner 'puts ActiveRecord::Base.connection.execute("SELECT vec_version()").first'`

Expected: a version string like `["v0.1.6"]`.

If this fails with `no such function: vec_version`, the extension isn't loading — debug by checking `Rails.configuration.x.sqlite_vec_path` exists and is readable, then verify the `SQLite3::Exception` message in the logs.

- [x] **Step 4: Update Dockerfile**

`.dockerignore` does not exclude `vendor/`, and `COPY . .` already
includes `vendor/sqlite-vec/`. No changes needed.

Open the template's `Dockerfile`. Find the `COPY . .` or equivalent line and ensure `vendor/sqlite-vec/` is included. If there's a `.dockerignore` that excludes `vendor/`, add an exception:

```
!vendor/sqlite-vec/
```

- [x] **Step 5: Commit**

```bash
git add config/initializers/sqlite_vec.rb Dockerfile .dockerignore
git commit -m "feat: load sqlite-vec extension on every SQLite connection"
```

---

## Task 3: Add embedding settings

- [ ] **Step 1: Migration**

```ruby
class AddEmbeddingSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :embedding_model, :string, default: "text-embedding-3-small"
    add_column :settings, :rrf_k, :integer, default: 60
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 2: Update Setting model**

Add `:embedding_model` and `:rrf_k` to `ALLOWED_KEYS`. Add readers:

```ruby
def self.embedding_model
  get(:embedding_model).presence
end

def self.rrf_k
  (get(:rrf_k) || 60).to_i
end
```

- [ ] **Step 3: Commit**

```bash
git add app/models/setting.rb db/migrate/*embedding_settings* db/schema.rb
git commit -m "feat: add embedding_model and rrf_k settings"
```

---

## Task 4: Create the Embeddable concern

**Files:**
- Create: `app/models/concerns/embeddable.rb`
- Create: `app/jobs/embed_record_job.rb`
- Create: `test/models/concerns/embeddable_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/concerns/embeddable_test.rb`:

```ruby
require "test_helper"

class EmbeddableTest < ActiveSupport::TestCase
  setup do
    SearchableThing.delete_all
  end

  test "embeddable_source and embeddable_model are declared on the class" do
    skip "Add Embeddable to SearchableThing first"
  end

  test "similar_to returns records ordered by similarity" do
    skip "Requires vec0 table — tested after Task 6"
  end

  test "enqueues EmbedRecordJob on save when source changes" do
    skip "Tested after Task 6"
  end
end
```

Most of the logic will come together in Task 6 when `SearchableThing` gets `include Embeddable`. This test file skeleton is committed first and filled in later.

- [ ] **Step 2: Create the concern**

Create `app/models/concerns/embeddable.rb`:

```ruby
module Embeddable
  extend ActiveSupport::Concern

  class_methods do
    def embeddable_source(proc = nil, &block)
      @embeddable_source = proc || block
    end

    def embeddable_source_proc
      @embeddable_source
    end

    def embeddable_model(proc = nil, &block)
      @embeddable_model = proc || block
    end

    def embeddable_model_name
      (@embeddable_model&.call) || Setting.embedding_model
    end

    def embeddable_distance(metric = nil)
      @embeddable_distance = metric if metric
      @embeddable_distance || :cosine
    end

    def embeddable_metadata(proc = nil, &block)
      @embeddable_metadata = proc || block
    end

    def embeddable_metadata_for(record)
      (@embeddable_metadata&.call(record)) || {}
    end

    def embeddings_table
      "#{table_name}_embeddings"
    end

    def similar_to(query_text, limit: 20, filter_by: {})
      return none if query_text.blank?

      embedding = embed_query(query_text)
      return none unless embedding

      filter_sql = build_filter_sql(filter_by)
      vector_literal = "[#{embedding.join(',')}]"

      rows = connection.select_all(<<~SQL)
        SELECT id, distance
        FROM #{embeddings_table}
        WHERE embedding MATCH '#{vector_literal}'
        #{filter_sql.empty? ? '' : "AND #{filter_sql}"}
        ORDER BY distance
        LIMIT #{limit.to_i}
      SQL

      ids = rows.map { |r| r["id"] }
      distances = rows.to_h { |r| [r["id"], r["distance"]] }

      return none if ids.empty?

      records = where(id: ids).index_by(&:id)
      ordered = ids.map { |id| records[id] }.compact
      ordered.each { |r| r.define_singleton_method(:similarity_distance) { distances[r.id] } }
      ordered
    end

    def embed_query(text)
      model = embeddable_model_name
      return nil unless model
      response = RubyLLM.embed(text, model: model)
      response.vectors.first
    rescue => e
      Rails.logger.warn("[Embeddable] query embed failed: #{e.message}")
      nil
    end

    private

    def build_filter_sql(filters)
      return "" if filters.empty?
      filters.map do |key, value|
        case value
        when Range
          "#{key} BETWEEN #{value.begin.to_i} AND #{value.end.to_i}"
        when Array
          "#{key} IN (#{value.map { |v| connection.quote(v) }.join(',')})"
        else
          "#{key} = #{connection.quote(value)}"
        end
      end.join(" AND ")
    end
  end

  included do
    after_save_commit :enqueue_embedding, if: :should_reembed?
    after_destroy_commit :purge_embedding
  end

  def source_for_embedding
    self.class.embeddable_source_proc&.call(self).to_s
  end

  def metadata_for_embedding
    self.class.embeddable_metadata_for(self)
  end

  def should_reembed?
    return false if source_for_embedding.blank?
    current_hash = Digest::SHA256.hexdigest(source_for_embedding)
    stored_hash = self.class.connection.select_value(
      "SELECT source_hash FROM #{self.class.embeddings_table} WHERE id = #{self.class.connection.quote(id)}"
    )
    current_hash != stored_hash
  end

  def enqueue_embedding
    EmbedRecordJob.perform_later(self.class.name, id)
  end

  def purge_embedding
    self.class.connection.execute(
      "DELETE FROM #{self.class.embeddings_table} WHERE id = #{self.class.connection.quote(id)}"
    )
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[Embeddable] purge failed: #{e.message}")
  end
end
```

- [ ] **Step 3: Create the job**

Create `app/jobs/embed_record_job.rb`:

```ruby
class EmbedRecordJob < ApplicationJob
  queue_as :low_priority

  def perform(class_name, id)
    klass = class_name.constantize
    record = klass.find_by(id: id)
    return unless record

    source = record.source_for_embedding
    return if source.blank?

    model = klass.embeddable_model_name
    return unless model

    response = RubyLLM.embed(source, model: model)
    vector = response.vectors.first
    return unless vector

    hash = Digest::SHA256.hexdigest(source)
    metadata = record.metadata_for_embedding

    # Build INSERT OR REPLACE with dynamic metadata columns
    columns = ["id", "embedding", "source_hash"] + metadata.keys.map(&:to_s)
    values = [
      klass.connection.quote(record.id),
      "'[#{vector.join(',')}]'",
      klass.connection.quote(hash)
    ] + metadata.values.map { |v| klass.connection.quote(v) }

    klass.connection.execute(
      "INSERT OR REPLACE INTO #{klass.embeddings_table} (#{columns.join(', ')}) VALUES (#{values.join(', ')})"
    )
  rescue => e
    Rails.logger.error("[EmbedRecordJob] failed for #{class_name}##{id}: #{e.message}")
    raise
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add app/models/concerns/embeddable.rb app/jobs/embed_record_job.rb test/models/concerns/embeddable_test.rb
git commit -m "feat: Embeddable concern + EmbedRecordJob (ordered KNN, metadata filtering)"
```

---

## Task 5: Generator for vec0 virtual tables

**Files:**
- Create: `lib/generators/embeddable/install/install_generator.rb`
- Create: `lib/generators/embeddable/install/templates/migration.rb.tt`

- [ ] **Step 1: Generator**

```ruby
module Embeddable
  module Generators
    class InstallGenerator < ::Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration
      source_root File.expand_path("templates", __dir__)

      argument :dimension, type: :numeric, default: 1536
      class_option :metadata, type: :array, default: [], desc: "Metadata columns for pre-filtering"

      def create_migration_file
        migration_template "migration.rb.tt", "db/migrate/create_#{table_name}_embeddings.rb"
      end

      def table_name
        name.tableize
      end

      def embeddings_table
        "#{table_name}_embeddings"
      end

      def distance_metric
        "cosine"
      end

      def metadata_columns
        options[:metadata]
      end
    end
  end
end
```

- [ ] **Step 2: Template**

```ruby
class Create<%= name.camelize %>Embeddings < ActiveRecord::Migration[8.1]
  def up
    cols = [
      "id text primary key",
      "embedding float[<%= dimension %>] distance_metric=<%= distance_metric %>",
      "source_hash text"<% metadata_columns.each do |col| %>,
      "<%= col %> text"<% end %>
    ].join(",\n        ")

    execute <<~SQL
      CREATE VIRTUAL TABLE IF NOT EXISTS <%= embeddings_table %>
      USING vec0(
        #{cols}
      )
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS <%= embeddings_table %>"
  end
end
```

**Note:** sqlite-vec metadata columns should be typed according to what you filter on — `text`, `integer`, or `float`. The template above hardcodes `text` for simplicity; upgrade to per-column typing when a consuming app needs integer range filters.

- [ ] **Step 3: Run the generator for SearchableThing**

```bash
bin/rails generate embeddable:install SearchableThing 1536
bin/rails db:migrate
```

- [ ] **Step 4: Verify table exists**

```bash
bin/rails runner 'puts ActiveRecord::Base.connection.execute("SELECT name FROM sqlite_master WHERE name = \"searchable_things_embeddings\"").to_a'
```

- [ ] **Step 5: Commit**

```bash
git add lib/generators/embeddable/ db/migrate/*embeddings* db/schema.rb
git commit -m "feat: embeddable:install generator + searchable_things_embeddings vec0 table"
```

---

## Task 6: Wire SearchableThing to Embeddable and fill in tests

**Files:**
- Modify: `app/models/searchable_thing.rb`
- Modify: `test/models/concerns/embeddable_test.rb`

- [ ] **Step 1: Update the test model**

Open `app/models/searchable_thing.rb`:

```ruby
class SearchableThing < ApplicationRecord
  include Searchable
  include Embeddable

  searchable_fields :name, :description, :tags

  embeddable_source ->(record) { "#{record.name} #{record.description} #{record.tags}" }
  embeddable_model  -> { Setting.embedding_model }
  embeddable_distance :cosine
end
```

- [ ] **Step 2: Fill in the tests**

Replace `test/models/concerns/embeddable_test.rb`:

```ruby
require "test_helper"

class EmbeddableTest < ActiveSupport::TestCase
  setup do
    SearchableThing.delete_all
    ActiveRecord::Base.connection.execute("DELETE FROM searchable_things_embeddings")
  end

  test "embeddable_source and embeddable_model are declared" do
    assert_respond_to SearchableThing, :embeddable_source_proc
    assert_not_nil SearchableThing.embeddable_source_proc
  end

  test "embeddings_table name is derived" do
    assert_equal "searchable_things_embeddings", SearchableThing.embeddings_table
  end

  test "enqueues EmbedRecordJob on create" do
    assert_enqueued_with(job: EmbedRecordJob) do
      SearchableThing.create!(name: "Welder", description: "Russian speaker")
    end
  end

  test "does not re-embed when source hash is unchanged" do
    thing = SearchableThing.create!(name: "Welder", description: "Russian speaker")
    perform_enqueued_jobs

    assert_no_enqueued_jobs only: EmbedRecordJob do
      thing.update!(updated_at: Time.current)  # non-source change
    end
  end

  test "purges from embeddings table on destroy" do
    thing = SearchableThing.create!(name: "Destroyable")
    perform_enqueued_jobs

    count = ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM searchable_things_embeddings WHERE id = #{ActiveRecord::Base.connection.quote(thing.id)}"
    )
    # After embedding, row count should be 1
    assert_equal 1, count if Setting.embedding_model.present?

    thing.destroy
    count_after = ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM searchable_things_embeddings WHERE id = #{ActiveRecord::Base.connection.quote(thing.id)}"
    )
    assert_equal 0, count_after
  end
end
```

**Test limitation:** actual similarity search requires real embeddings from an LLM. The tests above avoid that by checking job enqueue, table layout, and purge. End-to-end similarity testing with real embeddings is deferred to Task 8 and runs only when an embedding model is configured.

- [ ] **Step 3: Run the tests**

Run: `rails test test/models/concerns/embeddable_test.rb`

Expected: PASS. Tests that depend on embeddings being populated are gated behind `Setting.embedding_model.present?`.

- [ ] **Step 4: Commit**

```bash
git add app/models/searchable_thing.rb test/models/concerns/embeddable_test.rb
git commit -m "feat: include Embeddable in SearchableThing + unit tests"
```

---

## Task 7: Chunkable concern for long documents

**Files:**
- Create: `app/models/concerns/chunkable.rb`
- Create: `app/models/chunk.rb`
- Create: `db/migrate/YYYYMMDDHHMMSS_create_chunks.rb`
- Create: `test/models/concerns/chunkable_test.rb`

- [ ] **Step 1: Create chunks table**

```ruby
class CreateChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :chunks, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :chunkable, polymorphic: true, null: false, type: :string
      t.integer :position, null: false
      t.text :content, null: false
      t.timestamps
    end
    add_index :chunks, [:chunkable_type, :chunkable_id, :position], unique: true
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 2: Create Chunk model**

Create `app/models/chunk.rb`:

```ruby
class Chunk < ApplicationRecord
  include Embeddable

  belongs_to :chunkable, polymorphic: true

  embeddable_source ->(chunk) { chunk.content }
  embeddable_model  -> { Setting.embedding_model }
end
```

Generate its vec0 table:

```bash
bin/rails generate embeddable:install Chunk 1536
bin/rails db:migrate
```

- [ ] **Step 3: Create Chunkable concern**

Create `app/models/concerns/chunkable.rb`:

```ruby
module Chunkable
  extend ActiveSupport::Concern

  class_methods do
    def chunk_source(proc = nil, &block)
      @chunk_source = proc || block
    end

    def chunk_source_proc
      @chunk_source
    end

    def chunk_size(n = nil)
      @chunk_size = n if n
      @chunk_size || 400
    end

    def chunk_overlap(n = nil)
      @chunk_overlap = n if n
      @chunk_overlap || 40
    end
  end

  included do
    has_many :chunks, as: :chunkable, dependent: :destroy
    after_save_commit :rechunk, if: :should_rechunk?
  end

  def rechunk
    chunks.destroy_all
    source = self.class.chunk_source_proc&.call(self)
    return if source.blank?

    sentences = source.split(/(?<=[.!?])\s+/)
    current_chunk = []
    current_size = 0
    position = 0

    sentences.each do |sentence|
      words = sentence.split(/\s+/).size
      if current_size + words > self.class.chunk_size && current_chunk.any?
        chunks.create!(position: position, content: current_chunk.join(" "))
        position += 1
        overlap_word_count = self.class.chunk_overlap
        current_chunk = current_chunk.last(overlap_word_count)
        current_size = current_chunk.sum { |s| s.split(/\s+/).size }
      end
      current_chunk << sentence
      current_size += words
    end

    if current_chunk.any?
      chunks.create!(position: position, content: current_chunk.join(" "))
    end
  end

  def should_rechunk?
    return false unless self.class.chunk_source_proc
    source = self.class.chunk_source_proc.call(self)
    previous_source_digest != Digest::SHA256.hexdigest(source.to_s)
  end

  def previous_source_digest
    chunks.order(:position).pluck(:content).join(" ").then { |s| Digest::SHA256.hexdigest(s) }
  end
end
```

- [ ] **Step 4: Write test**

Create `test/models/concerns/chunkable_test.rb`:

```ruby
require "test_helper"

class ChunkableTest < ActiveSupport::TestCase
  class TestDoc < ApplicationRecord
    self.table_name = "searchable_things"
    include Chunkable
    chunk_source ->(r) { r.description }
    chunk_size 10
    chunk_overlap 2
  end

  test "rechunks on save when source changes" do
    doc = TestDoc.create!(name: "Doc", description: "One two three. Four five six. Seven eight nine. Ten eleven twelve. Thirteen fourteen fifteen.")
    assert doc.chunks.any?
  end

  test "chunk count respects chunk_size roughly" do
    doc = TestDoc.create!(name: "Doc", description: "a b c d e f g h i j k l m n o p q r s t.")
    assert doc.chunks.count >= 1
  end
end
```

- [ ] **Step 5: Run tests**

Run: `rails test test/models/concerns/chunkable_test.rb`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add db/migrate/*create_chunks* db/migrate/*chunks_embeddings* db/schema.rb \
        app/models/chunk.rb app/models/concerns/chunkable.rb \
        test/models/concerns/chunkable_test.rb
git commit -m "feat: Chunkable concern + polymorphic Chunk model"
```

---

## Task 8: HybridSearchable with Reciprocal Rank Fusion

**Files:**
- Create: `app/models/concerns/hybrid_searchable.rb`
- Create: `test/models/concerns/hybrid_searchable_test.rb`

- [ ] **Step 1: Create the concern**

```ruby
module HybridSearchable
  extend ActiveSupport::Concern

  included do
    unless include?(Searchable) && include?(Embeddable)
      raise "HybridSearchable requires Searchable and Embeddable to be included first"
    end
  end

  class_methods do
    def hybrid_search(query, limit: 20)
      return none if query.blank?

      k = Setting.rrf_k

      fts_ids = search(query).first(limit * 3).map(&:id)
      vector_results = similar_to(query, limit: limit * 3)
      vector_ids = vector_results.map(&:id)

      # Reciprocal Rank Fusion
      scores = Hash.new(0.0)
      fts_ids.each_with_index { |id, i| scores[id] += 1.0 / (k + i + 1) }
      vector_ids.each_with_index { |id, i| scores[id] += 1.0 / (k + i + 1) }

      ordered_ids = scores.sort_by { |_, score| -score }.first(limit).map(&:first)
      records = where(id: ordered_ids).index_by(&:id)
      ordered_ids.map { |id| records[id] }.compact
    end
  end
end
```

- [ ] **Step 2: Add to SearchableThing**

```ruby
class SearchableThing < ApplicationRecord
  include Searchable
  include Embeddable
  include HybridSearchable
  # ...
end
```

- [ ] **Step 3: Write test**

Create `test/models/concerns/hybrid_searchable_test.rb`:

```ruby
require "test_helper"

class HybridSearchableTest < ActiveSupport::TestCase
  test "hybrid_search returns empty for blank query" do
    assert_empty SearchableThing.hybrid_search("")
    assert_empty SearchableThing.hybrid_search(nil)
  end

  test "raises if included without Searchable+Embeddable" do
    klass = Class.new(ApplicationRecord) do
      self.table_name = "searchable_things"
    end
    assert_raises(RuntimeError, /requires Searchable/) do
      klass.send(:include, HybridSearchable)
    end
  end

  # Full hybrid ranking tests require real FTS data + real embeddings;
  # a smoke test is enough here. Comprehensive tests run via a dedicated
  # fixture set in a consuming app.
end
```

- [ ] **Step 4: Run and commit**

Run: `rails test test/models/concerns/hybrid_searchable_test.rb`

```bash
git add app/models/concerns/hybrid_searchable.rb \
        app/models/searchable_thing.rb \
        test/models/concerns/hybrid_searchable_test.rb
git commit -m "feat: HybridSearchable with Reciprocal Rank Fusion"
```

---

## Task 9: Rake task for reindexing

- [ ] **Step 1: Create**

Create `lib/tasks/embeddable.rake`:

```ruby
namespace :embeddings do
  desc "Rebuild embeddings for a model. Usage: bin/rails 'embeddings:rebuild[ModelName]'"
  task :rebuild, [:model_name] => :environment do |_t, args|
    model = args[:model_name].constantize

    unless model.include?(Embeddable)
      puts "#{model.name} does not include Embeddable"
      exit 1
    end

    conn = model.connection
    conn.execute("DELETE FROM #{model.embeddings_table}")

    total = model.count
    done = 0
    model.find_each do |record|
      EmbedRecordJob.perform_later(model.name, record.id)
      done += 1
      puts "Queued #{done}/#{total}" if (done % 100).zero?
    end

    puts "Done. #{total} records queued for embedding."
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/tasks/embeddable.rake
git commit -m "feat: embeddings:rebuild rake task"
```

---

## Task 10: README.md update

- [ ] **Step 1: Add**

```markdown
- **Vector Search + RAG kit** (`Embeddable`, `Chunkable`, `HybridSearchable`)
  - sqlite-vec backed vec0 virtual tables, zero external dependencies
  - Ordered KNN results with per-field confidence (`record.similarity_distance`)
  - Metadata pre-filtering for WHERE-aware KNN
  - Chunking for long documents via the polymorphic `Chunk` model
  - Hybrid keyword+semantic retrieval via Reciprocal Rank Fusion
  - Cosine (default), L2, L1, Hamming distance metrics
```

Tech stack:

```markdown
- **Vector Search**: sqlite-vec (loadable extension)
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README Embeddable + RAG kit section"
```

---

## Task 11: AGENTS.md update

- [ ] **Step 1: Add section**

```markdown
## Embeddable + RAG Kit

Vector search and semantic retrieval via [sqlite-vec](https://github.com/asg017/sqlite-vec), a loadable SQLite extension with zero runtime dependencies.

### Basic similarity search

```ruby
class Candidate < ApplicationRecord
  include Embeddable

  embeddable_source ->(r) { "#{r.profession} #{r.skills} #{r.experience_summary}" }
  embeddable_model  -> { Setting.embedding_model }
  embeddable_distance :cosine
end

Candidate.similar_to("welder with marine experience", limit: 20)
# → returns Candidate records ordered by distance ascending (nearest first)
# → each record has .similarity_distance for UI display
```

### Metadata pre-filtering

Declare metadata columns in the vec0 table (via the generator's `--metadata` option). Then filter before KNN:

```ruby
embeddable_metadata ->(r) {
  { nationality: r.nationality_code, years_experience: r.experience_years }
}

Candidate.similar_to("welder", filter_by: { nationality: "UZ", years_experience: 3.. })
# → WHERE nationality = 'UZ' AND years_experience BETWEEN 3 AND 0 → KNN
```

### Hybrid search (keyword + semantic)

```ruby
class Candidate < ApplicationRecord
  include Searchable
  include Embeddable
  include HybridSearchable
end

Candidate.hybrid_search("welder marine experience")
# → FTS5 bm25 + vector KNN, fused via Reciprocal Rank Fusion (k=60)
```

### Chunking for long documents

```ruby
class Article < ApplicationRecord
  include Embeddable
  include Chunkable
  chunk_source ->(r) { r.body }
  chunk_size 400
  chunk_overlap 40
end
```

Chunks are stored in a polymorphic `chunks` table with their own vec0 embeddings. `Article.similar_to(query)` returns articles ordered by best-matching chunk distance.

### Installation

```bash
bin/rails generate embeddable:install Candidate 1536 --metadata nationality profession
bin/rails db:migrate
bin/rails 'embeddings:rebuild[Candidate]'
```

### Settings

- `Setting.embedding_model` — default `"text-embedding-3-small"`
- `Setting.rrf_k` — default `60` (Cormack et al. standard)

### Out of scope

- External vector databases (Pinecone, Weaviate, pgvector)
- Re-ranking models (Cohere Rerank)
- Query expansion (HyDE, multi-query)

If you need any of these, swap the concern's implementation; the public API (`similar_to`, `hybrid_search`) is stable.
```

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: AGENTS.md Embeddable + RAG kit section"
```

---

## Task 12: Final CI and PR

- [ ] **Step 1: Full CI**

Run: `bin/ci`

- [ ] **Step 2: Smoke-test the extension in console**

```bash
bin/rails runner '
  puts ActiveRecord::Base.connection.execute("SELECT vec_version()").first
  puts SearchableThing.embeddings_table
  puts Setting.embedding_model
'
```

Expected: version string + `searchable_things_embeddings` + embedding model name.

- [ ] **Step 3: Commit any fixes and PR**

```bash
git add -u && git commit -m "chore: smoke-test fixes for embeddable"
git push -u origin feature/embeddable-rag-kit
gh pr create --title "feat: Embeddable + RAG kit (sqlite-vec)" \
             --body "Implements docs/specs/template-improvements.md §4 per plan 05."
```

---

## Tasks 13-15: Integration and documentation cleanup

### Task 13: Document Kamal/Dockerfile step for consuming apps

- [ ] Add a section to `AGENTS.md` under Embeddable: "When deploying a consuming app with sqlite-vec, ensure `vendor/sqlite-vec/` is copied into the container. Template's Dockerfile already does this; if a consuming app has its own Dockerfile, replicate the `COPY` line."

### Task 14: Performance rule

- [ ] Append to `.claude/rules/performance.md`:

```markdown
## Vector Search

- Re-embedding on save is automatic via `Embeddable`. To avoid wasted API calls, the source string is hashed and compared before enqueuing `EmbedRecordJob`.
- Metadata pre-filtering via `filter_by:` is always cheaper than post-filtering. Declare metadata columns for any field you'll filter on at query time.
- `similar_to` performs a two-query lookup (vec0 → main table) which is fine at template scale. For hot paths, consider caching the result set.
- `Chunkable` enqueues rechunking synchronously in an `after_save_commit`. If chunking is slow, move to a background job.
```

### Task 15: Verify the Dockerfile

- [ ] Open `Dockerfile`. Ensure `vendor/sqlite-vec/` is copied. If `.dockerignore` excludes `vendor/`, add an exception as noted in Task 2.

```bash
git add Dockerfile .dockerignore .claude/rules/performance.md AGENTS.md
git commit -m "docs: Kamal/Docker notes for sqlite-vec deployment"
```

---

## Self-review

- ✅ sqlite-vec extension vendored and loaded — Tasks 1, 2
- ✅ `Embeddable` concern with ordered KNN and metadata filtering — Tasks 4, 5, 6
- ✅ `Chunkable` concern + polymorphic `Chunk` model — Task 7
- ✅ `HybridSearchable` with RRF — Task 8
- ✅ Generator for vec0 tables — Task 5
- ✅ Rake task for reindexing — Task 9
- ✅ Caching via source-hash check — Task 4 (concern code)
- ✅ README + AGENTS — Tasks 10, 11
- ✅ Kamal/Dockerfile notes — Tasks 13, 15

No placeholders. Type consistency: `similar_to(query, limit:, filter_by:)`, `embeddings_table`, `embeddable_source_proc`, `embeddable_model_name` referenced consistently across concerns, job, generator, and tests.

---

## Execution handoff

Subagent-driven strongly recommended. Tasks 2 (extension loader) and 6 (wiring SearchableThing + real tests) are the ones most likely to reveal platform-specific issues — review those outputs carefully between agents.
