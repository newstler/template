# RubyLLM 2.0 Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `ruby_llm` 1.16.0 (current `origin/main`, bumped by Dependabot without code changes) → 2.0.0, hand model / tool-call / usage persistence to the gem, read all chat cost + token data from `ruby_llm_usages`, and ship an upgrade check so the five downstream apps can follow with one merge + one `db:migrate`.

**Architecture:** Stabilise 1.16 (the schema the 2.0 upgrade generator expects), then run the gem's generator in **rename mode** (prepare → backfill → finish → cleanup) with three template-specific patches. Delete the app's `Model`, `ToolCall` and `Costable`; use `RubyLLM::ActiveRecord::Model` / `RubyLLM::ActiveRecord::ToolCall` directly, extended with one app concern (`Enableable`) for the provider-credential scopes. Drop every app-owned cost/token cache (`messages.cost`, `chats.total_cost`, `users.total_cost`, `ruby_llm_models.chats_count/total_cost`) and compute costs from `ruby_llm_usages` via correlated-subquery scopes.

**Tech Stack:** Rails main, Ruby 4.0.3 (rbenv), SQLite (string UUIDv7 PKs, `uuid7()` default), ruby_llm 2.0.0, Madmin 2.6.0, fast-mcp, Minitest + fixtures.

**Spec:** This plan (decisions agreed in conversation on 2026-09-23): generator rename mode; follow the RubyLLM-recommended path (no app `Model` wrapper); cost tracking switched to RubyLLM usages. Upstream guide: https://rubyllm.com/next/upgrading/ . Gem source for reference: `gem fetch ruby_llm -v 2.0.0 && gem unpack ruby_llm-2.0.0.gem`.

## Global Constraints

- `gem "ruby_llm", "~> 2.0"` in the final Gemfile (not `~> 2.0.0` — every downstream app upgrades now; note in UPGRADING.md that the generated migrations `require` gem internals, so a from-scratch `db:migrate` on a far-future 2.x may need `db:schema:load` instead); `ruby_llm-schema` must not be referenced by app code.
- Work happens on a `ruby-llm-2` branch in the template **and** in every downstream app. Nothing is pushed or merged without the user's go-ahead.
- Every new table uses `id: :string, default: -> { "uuid7()" }` (AGENTS.md "Migrations with UUIDv7"). **This includes the generator's `ruby_llm_usages` and `ruby_llm_batches`.**
- No LLM model name string literals in `app/` — models come from `Setting.*_model` (AGENTS.md "Nothing hardcoded").
- Every user-facing string via i18n; en + ru locale files updated together; `bundle exec i18n-tasks health` clean.
- Every Madmin index column sortable (`.claude/rules/madmin.md`); computed columns sort in `scoped_resources`.
- No N+1: `includes` for every association a view/tool touches; no `.count` on associations with counter caches.
- MCP parity: every changed controller behaviour keeps a matching tool (AGENTS.md "Agent-Native Development Rule").
- No `after_commit` side effects added (memory: explicit actions over callbacks). No `OpenStruct`.
- `bin/ci` green before the final commit. Intermediate tasks may leave unrelated suites red **only** between Task 3 and Task 8; each task names the test files that must pass at its end.

## Review Focus

1. **Existing chat data survives the migration** — a chat with messages, a tool call + tool result, token counts and a `cost` must, after `db:migrate`, still show its messages, tool call, tokens and cost (Task 3 migration test).
2. **Backfilled usage rows carry the real model name, not a UUID** — `ruby_llm_usages.model` must equal `"gpt-4"`, never `01961a2a-…` (Task 3 migration test).
3. **Assistant messages with no model anywhere** — prepare validation raises; the pre-flight migration must repair them from `Setting.default_model` rather than aborting a fork's deploy (Task 3 migration test).
4. **Cost of a chat with a failed/unpriced attempt** — `total_cost` NULL on one usage row must not blank the whole chat's cost in Madmin/MCP (use `COALESCE(SUM(...), 0)`; Task 6 test).
5. **Model refresh deletes unreferenced rows** — `RubyLLM.models.refresh` destroys registry rows no chat references; the Madmin refresh must not break `Setting.default_model` selection or pages when the selected model has no chats (Task 5 test).

---

## File Structure

**Delete**
- `app/models/model.rb`, `app/models/tool_call.rb`, `app/models/concerns/costable.rb`
- `test/models/model_test.rb`, `test/models/tool_call_test.rb`, `test/fixtures/models.yml`, `test/fixtures/tool_calls.yml`

**Create**
- `app/models/concerns/enableable.rb` — `enabled` / `embedding` scopes mixed into `RubyLLM::ActiveRecord::Model`
- `config/initializers/ruby_llm_extensions.rb` — `to_prepare` hook that includes `Enableable`
- `db/migrate/<ts>_prepare_ruby_llm_v2_data.rb` — pre-flight data repair + `messages.cost → total_cost`
- `db/migrate/<ts>_{prepare,backfill,finish,cleanup}_ruby_llm_v2_*.rb` — generator output (patched)
- `db/migrate/<ts>_drop_app_cost_caches.rb`
- `test/fixtures/ruby_llm_models.yml`, `test/fixtures/ruby_llm_tool_calls.yml`, `test/fixtures/ruby_llm_usages.yml`
- `test/models/concerns/enableable_test.rb`, `test/migrations/ruby_llm_v2_upgrade_test.rb`

**Modify** (grouped by task below): `Gemfile`, `Gemfile.lock`, `config/initializers/ruby_llm.rb`, `config/environments/test.rb`, `app/models/{chat,message,user,team,ai_cost,setting,provider_credential}.rb`, `app/jobs/{chat_response,translate_content,moderate_message,embed_record,rebuild_all_embeddings}_job.rb`, `app/models/concerns/embeddable.rb`, `app/controllers/{chats,models}_controller.rb`, `app/controllers/models/refreshes_controller.rb`, `app/controllers/madmin/{ai_models,models,chats,messages,teams,users,tool_calls,dashboard}_controller.rb`, `app/madmin/resources/{model,tool_call,chat,message,team,user}_resource.rb`, `app/tools/{models,chats,messages,users,teams}/*`, `app/resources/mcp/available_models_resource.rb`, views under `app/views/{chats,messages,models,madmin}/`, `lib/tasks/counter_cache.rake`, locale files, `AGENTS.md`, and every affected test.

---

### Task 1: Environment + stabilise 1.16

`origin/main` already runs ruby_llm 1.16.0 (Dependabot) with no code changes, so the 1.15 `Message#cost` shadowing is live on `main`. This task makes `main`'s 1.16 state green before the 2.0 work.

**Files:**
- Modify: `.ruby-version`, `Dockerfile:11`, `app/models/message.rb`, `config/environments/test.rb`
- Test: `test/models/message_test.rb`

**Interfaces:**
- Produces: app green on ruby_llm 1.16.0 with `Message#cost` returning the decimal column.

- [ ] **Step 1: Branch and toolchain**

```bash
git checkout -b ruby-llm-2
echo 4.0.3 > .ruby-version             # rbenv has 4.0.3; 4.0.1 isn't installed. Downstream apps are on 4.0.3.
sed -i '' 's/ARG RUBY_VERSION=4.0.0/ARG RUBY_VERSION=4.0.3/' Dockerfile
gem install bundler:4.0.5
bundle install
bin/rails test     # baseline: record pre-existing failures (expect Message#cost ones) before touching code
git commit -am "chore: pin Ruby 4.0.3 in .ruby-version and Dockerfile"
```

- [ ] **Step 2: Write the failing test** — 1.15 adds `MessageMethods#cost` returning `RubyLLM::Cost`, shadowing the column. Append to `test/models/message_test.rb`:

```ruby
test "cost reads the stored decimal column" do
  assert_kind_of BigDecimal, messages(:assistant_message).cost
  assert_in_delta 0.0012, messages(:assistant_message).cost
end
```

- [ ] **Step 3: (no gem change — `Gemfile.lock` already has 1.16.0)**

- [ ] **Step 4: Run test to verify it fails**

Run: `bin/rails test test/models/message_test.rb`
Expected: FAIL — `Expected #<RubyLLM::Cost …> to be a kind of BigDecimal`.

- [ ] **Step 5: Minimal fix** — in `app/models/message.rb` directly under `acts_as_message …` add:

```ruby
  # ruby_llm 1.15+ defines #cost from tokens; keep the stored column until the 2.0 schema lands.
  def cost = self[:cost]
```

and in `config/environments/test.rb` inside the configure block:

```ruby
  config.after_initialize { RubyLLM.configure { |c| c.deprecation_behavior = :raise } }
```

- [ ] **Step 6: Run the full suite**

Run: `bin/ci`
Expected: PASS (same as baseline). Any `RubyLLM::DeprecationError` points at a call removed in 2.0 — fix it here using the rename tables in the upgrade guide.

- [ ] **Step 7: Commit**

```bash
git add app/models/message.rb config/environments/test.rb test/models/message_test.rb
git commit -m "fix(chat): keep Message#cost on the stored column under ruby_llm 1.16"
```

---

### Task 2: Pre-flight data migration (still on 1.16)

**Files:**
- Create: `db/migrate/<ts>_prepare_ruby_llm_v2_data.rb`, `test/migrations/ruby_llm_v2_upgrade_test.rb`
- Modify: `app/models/message.rb` (column rename), `db/schema.rb`, `test/fixtures/messages.yml`

**Why:** the 2.0 backfill (a) only carries cost from `messages.total_cost`, not `messages.cost`; (b) reads a *string* `messages.model_id` as a model **name**, but ours holds a `models.id` UUID; (c) raises if an assistant message resolves no model at all.

**Interfaces:**
- Produces: `messages.total_cost` (decimal), `messages.model_id` holding a **model name** (`models.model_id`) and new `messages.provider` string, every chat with a `model_id`.

- [ ] **Step 1: Write the failing migration test** — `test/migrations/ruby_llm_v2_upgrade_test.rb`:

```ruby
require "test_helper"
require Rails.root.join("db/migrate", Dir.children(Rails.root.join("db/migrate")).grep(/prepare_ruby_llm_v2_data/).first)

class RubyLlmV2UpgradeTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "pre-flight rewrites message model UUIDs to model names and keeps cost" do
    skip "runs only against the pre-2.0 schema" unless Message.column_names.include?("cost")

    connection = ActiveRecord::Base.connection
    PrepareRubyLlmV2Data.new.migrate(:up)
    Message.reset_column_information

    row = connection.select_one("SELECT model_id, provider, total_cost FROM messages WHERE id = '#{messages(:assistant_message).id}'")
    assert_equal "gpt-4", row["model_id"]
    assert_equal "openai", row["provider"]
    assert_in_delta 0.0012, row["total_cost"].to_f
  ensure
    connection&.rollback_transaction if connection&.transaction_open?
  end
end
```

(After Task 3 this test is superseded by the post-upgrade assertions added there; the `skip` keeps it green.)

- [ ] **Step 2: Run to verify it fails**

Run: `bin/rails test test/migrations/ruby_llm_v2_upgrade_test.rb`
Expected: FAIL — `cannot load such file` / `uninitialized constant PrepareRubyLlmV2Data`.

- [ ] **Step 3: Write the migration** — `bin/rails g migration PrepareRubyLlmV2Data`, body:

```ruby
class PrepareRubyLlmV2Data < ActiveRecord::Migration[8.1]
  # Shapes 1.x data the way ruby_llm's 2.0 upgrade generator expects. Irreversible.
  def up
    rename_column :messages, :cost, :total_cost
    add_column :messages, :provider, :string

    remove_foreign_key :messages, :models if foreign_key_exists?(:messages, :models)
    remove_index :messages, :model_id if index_exists?(:messages, :model_id)

    # messages.model_id held models.id (UUID); the generator reads a string column as the model name.
    execute <<~SQL
      UPDATE messages
      SET provider = (SELECT provider FROM models WHERE models.id = messages.model_id),
          model_id = (SELECT model_id FROM models WHERE models.id = messages.model_id)
      WHERE model_id IN (SELECT id FROM models)
    SQL

    # Assistant messages must resolve a model: fall back to the chat's model, then the configured default.
    execute <<~SQL
      UPDATE messages
      SET provider = (SELECT m.provider FROM chats c JOIN models m ON m.id = c.model_id WHERE c.id = messages.chat_id),
          model_id = (SELECT m.model_id FROM chats c JOIN models m ON m.id = c.model_id WHERE c.id = messages.chat_id)
      WHERE model_id IS NULL
    SQL

    default = select_value("SELECT value FROM settings WHERE key = 'default_model'") if table_exists?(:settings)
    default_row = default && select_one("SELECT id FROM models WHERE model_id = #{quote(default.to_s.delete('"'))}")
    execute "UPDATE chats SET model_id = #{quote(default_row['id'])} WHERE model_id IS NULL" if default_row
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

> Before running, check how `Setting` stores `default_model` (`app/models/setting.rb` `get`/`set`) and adjust the `settings` lookup SQL to that storage (column vs JSON). Keep the `if` guards so an empty DB migrates.

- [ ] **Step 4: Point code at the renamed column**

In `app/models/message.rb` change the Task 1 shim to `def cost = self[:total_cost]` and replace the writer in `calculate_cost` with `self.total_cost = …`; `after_update :update_cost_caches, if: :saved_change_to_total_cost?`; `cost_changed_from_default?` reads `total_cost`. In `test/fixtures/messages.yml` change `cost: 0.0012` → `total_cost: 0.0012` and `model_id: 01961a2a-c0de-7000-8000-000000000201` → `model_id: gpt-4` plus `provider: openai`. Grep for `sum(:cost)` (`app/models/chat.rb`, `lib/tasks/counter_cache.rake`) → `sum(:total_cost)`. (All of this is deleted in Task 4; it only keeps the suite green now.)

- [ ] **Step 5: Run migration + tests**

Run: `bin/rails db:migrate && bin/rails test test/migrations test/models/message_test.rb test/models/chat_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add db/migrate db/schema.rb app/models test/fixtures/messages.yml test/migrations lib/tasks/counter_cache.rake
git commit -m "chore(db): shape RubyLLM 1.x data for the 2.0 upgrade generator"
```

---

### Task 3: Gem 2.0 + generated upgrade migrations + core model layer

**Files:**
- Modify: `Gemfile`, `Gemfile.lock`, `config/initializers/ruby_llm.rb`, `app/models/chat.rb`, `app/models/message.rb`
- Create: generator migrations (prepare/backfill/finish), `app/models/concerns/enableable.rb`, `config/initializers/ruby_llm_extensions.rb`, `test/fixtures/ruby_llm_models.yml`, `test/fixtures/ruby_llm_tool_calls.yml`, `test/fixtures/ruby_llm_usages.yml`, `test/models/concerns/enableable_test.rb`
- Delete: `app/models/model.rb`, `app/models/tool_call.rb`, `test/models/model_test.rb`, `test/models/tool_call_test.rb`, `test/fixtures/models.yml`, `test/fixtures/tool_calls.yml`
- Test: `test/models/chat_test.rb`, `test/models/message_test.rb`, `test/models/concerns/enableable_test.rb`, `test/migrations/ruby_llm_v2_upgrade_test.rb`

**Interfaces:**
- Consumes: Task 2 schema.
- Produces:
  - `Chat` — `acts_as_chat`; `chat.model` → `RubyLLM::ActiveRecord::Model` (FK `ruby_llm_model_id`); `chat.model_id` → model **name** string; `chat.ruby_llm_usages`.
  - `Message` — `acts_as_message`; `message.tokens` (`RubyLLM::Tokens`: `.input .output .cache_read .cache_write .thinking`), `message.cost` (`RubyLLM::Cost`: `.total` may be nil), `message.model` (String), `message.tool_calls` (Hash of `RubyLLM::ToolCall`), `message.ruby_llm_tool_calls`, `message.ruby_llm_usages`.
  - `RubyLLM::ActiveRecord::Model.enabled` (listed + provider has credentials) and `.embedding`.
  - `ProviderCredential.configured_providers` → `Array<String>`.

- [ ] **Step 1: Bump + generate**

```bash
# Gemfile:74 → gem "ruby_llm", "~> 2.0"
bundle update ruby_llm
bin/rails g ruby_llm:upgrade        # rename mode; writes prepare, backfill, finish
```

- [ ] **Step 2: Patch generated migrations** (all three are template-specific fixes; leave a one-line comment on each)

1. `*_prepare_ruby_llm_v2_upgrade.rb`: both `create_table :ruby_llm_usages, id: :string` and `create_table :ruby_llm_batches, id: :string` → `id: :string, default: -> { "uuid7()" }` — otherwise the backfill's raw `INSERT` and runtime `create!` fail NOT NULL on `id`.
2. Confirm `usage_identity_sql` in prepare and backfill now takes the `model_column.type == :string` branch **and** picks up `messages.provider` (added in Task 2). No edit needed if so; if the generator did not detect `provider`, fix the branch to read it.
3. Run `grep -n "total_cost\|cost_details" db/migrate/*backfill_ruby_llm_v2_data.rb` and confirm `messages.total_cost` is copied into `ruby_llm_usages.total_cost`.

- [ ] **Step 3: Write failing model tests**

`test/models/chat_test.rb` — replace the two `formatted_total_cost` tests with:

```ruby
test "belongs to a RubyLLM registry model" do
  assert_instance_of RubyLLM::ActiveRecord::Model, chats(:one).model
  assert_equal "gpt-4", chats(:one).model_id
end

test "cost comes from recorded usages" do
  assert_in_delta 0.0012, chats(:one).cost.total
end
```

`test/models/message_test.rb` — delete the `formatted_cost` tests, the "calculates cost from model pricing" test and the Task 1 column test; add:

```ruby
test "exposes tokens and cost from its usage" do
  message = messages(:assistant_message)
  assert_equal 10, message.tokens.input
  assert_equal 15, message.tokens.output
  assert_in_delta 0.0012, message.cost.total
end

test "exposes tool calls from the gem table" do
  assert_equal "search", messages(:assistant_message).tool_calls.values.first.name
end
```

`test/models/concerns/enableable_test.rb`:

```ruby
require "test_helper"

class EnableableTest < ActiveSupport::TestCase
  test "enabled lists only models whose provider has credentials" do
    ProviderCredential.where(provider: "anthropic").delete_all
    assert_equal %w[openai], RubyLLM::ActiveRecord::Model.enabled.distinct.pluck(:provider)
  end

  test "enabled excludes unlisted models" do
    ruby_llm_models(:gpt4).update!(unlisted_at: Time.current)
    assert_not_includes RubyLLM::ActiveRecord::Model.enabled, ruby_llm_models(:gpt4)
  end

  test "embedding returns models that output embeddings" do
    assert_equal [ ruby_llm_models(:embedding_small) ], RubyLLM::ActiveRecord::Model.embedding.to_a
  end
end
```

- [ ] **Step 4: Fixtures**

Delete `models.yml`, `tool_calls.yml`. Create `test/fixtures/ruby_llm_models.yml` (check `pricing`/`modalities` shape against `RubyLLM::Model#pricing.to_h` / `#modalities.to_h` in the installed gem and match it):

```yaml
_fixture:
  model_class: RubyLLM::ActiveRecord::Model

gpt4:
  id: 01961a2a-c0de-7000-8000-000000000201
  model_id: gpt-4
  name: GPT-4
  provider: openai
  family: gpt-4
  context_window: 8192
  max_output_tokens: 4096
  modalities: { input: [text], output: [text] }
  capabilities: [function_calling]
  pricing: { text_tokens: { standard: { input_per_million: 30, output_per_million: 60, cached_input_per_million: 15 } } }

claude:
  id: 01961a2a-c0de-7000-8000-000000000202
  model_id: claude-3-opus-20240229
  name: Claude 3 Opus
  provider: anthropic
  family: claude-3
  context_window: 200000
  max_output_tokens: 4096
  modalities: { input: [text, image], output: [text] }
  capabilities: [function_calling, vision]
  pricing: { text_tokens: { standard: { input_per_million: 15, output_per_million: 75, cached_input_per_million: 7.5 } } }

embedding_small:
  id: 01961a2a-c0de-7000-8000-000000000203
  model_id: text-embedding-3-small
  name: Text Embedding 3 Small
  provider: openai
  family: text-embedding-3
  max_output_tokens: 1536
  modalities: { input: [text], output: [embeddings] }
  capabilities: []
  pricing: { text_tokens: { standard: { input_per_million: 0.02 } } }
```

`test/fixtures/ruby_llm_tool_calls.yml`:

```yaml
_fixture:
  model_class: RubyLLM::ActiveRecord::ToolCall

search_call:
  id: 01961a2a-c0de-7000-8000-000000000501
  message_type: Message
  message_id: 01961a2a-c0de-7000-8000-000000000402
  tool_call_id: call_abc123
  name: search
  arguments: { query: "weather in Paris" }
```

`test/fixtures/ruby_llm_usages.yml`:

```yaml
_fixture:
  model_class: RubyLLM::ActiveRecord::Usage

assistant_reply:
  id: 01961a2a-c0de-7000-8000-000000000601
  chat_type: Chat
  chat_id: 01961a2a-c0de-7000-8000-000000000301
  message_type: Message
  message_id: 01961a2a-c0de-7000-8000-000000000402
  operation: chat
  provider: openai
  model: gpt-4
  status: succeeded
  input_tokens: 10
  output_tokens: 15
  total_cost: 0.0012
```

`test/fixtures/chats.yml`: `model_id:` → `ruby_llm_model_id:` on both rows. `test/fixtures/messages.yml`: remove `model_id`, `provider`, token and cost keys (they're dropped in Task 4 — until then the columns are nullable after finish); update the header comment (no circular FK any more).

- [ ] **Step 5: Implement the model layer**

`config/initializers/ruby_llm.rb`:

```ruby
RubyLLM.configure do |config|
  model = Setting.default_model
  config.default_model = model if model.present?
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NameError
  # DB not ready yet (assets:precompile, first db:prepare)
end
```

`app/models/concerns/enableable.rb`:

```ruby
# Mixed into RubyLLM::ActiveRecord::Model: which registry models this install can actually call.
module Enableable
  extend ActiveSupport::Concern

  included do
    scope :enabled, -> { listed.where(provider: ProviderCredential.configured_providers) }
    scope :embedding, -> { where("json_extract(modalities, '$.output') LIKE '%embedding%'") }
  end
end
```

`config/initializers/ruby_llm_extensions.rb`:

```ruby
Rails.application.config.to_prepare do
  RubyLLM::ActiveRecord::Model.include(Enableable) unless RubyLLM::ActiveRecord::Model < Enableable
end
```

`app/models/provider_credential.rb` — add below `configured?`:

```ruby
  def self.configured_providers
    where(key: "api_key").where.not(value: [ nil, "" ]).distinct.pluck(:provider)
  end
```

`app/models/setting.rb:124` — `Model.configured_providers.any?` → `ProviderCredential.configured_providers.any?`.

`app/models/chat.rb`:

```ruby
class Chat < ApplicationRecord
  belongs_to :user
  belongs_to :team, optional: true
  acts_as_chat

  scope :chronologically, -> { order(updated_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }
end
```

`app/models/message.rb` — `acts_as_message` (no options); delete the `cost` shim, `before_save :calculate_cost`, `after_update :update_cost_caches`, `calculate_cost`, `formatted_cost`, `update_cost_caches`, `record_ai_cost`, `model_pricing`, `should_calculate_cost?`, `cost_changed_from_default?`; `increment_counters`/`decrement_counters` keep only the `messages_count` counter lines. Delete `app/models/model.rb`, `app/models/tool_call.rb`, `test/models/model_test.rb`, `test/models/tool_call_test.rb`.

- [ ] **Step 6: Post-upgrade migration assertions** — replace the body of `test/migrations/ruby_llm_v2_upgrade_test.rb` with checks that the fixtures-free dev DB round-trips (these run against the migrated schema):

```ruby
require "test_helper"

class RubyLlmV2UpgradeTest < ActiveSupport::TestCase
  test "schema is on the RubyLLM 2.0 layout" do
    connection = ActiveRecord::Base.connection
    assert connection.table_exists?(:ruby_llm_models)
    assert connection.table_exists?(:ruby_llm_usages)
    assert connection.column_exists?(:chats, :ruby_llm_model_id)
    assert_not connection.table_exists?(:models)
  end

  test "usage rows get uuid7 primary keys" do
    usage = chats(:one).ruby_llm_usages.create!(operation: "chat", provider: "openai", model: "gpt-4", status: "succeeded")
    assert_match(/\A\h{8}-\h{4}-7\h{3}-/, usage.id)
  end
end
```

Then rehearse the upgrade on real-shaped data once, by hand, and record the result in the commit message:

```bash
git stash -- db/ && git checkout main -- db/ && bin/rails db:reset && bin/rails runner '
  u = User.first || User.create!(email: "r@example.com", name: "R")
  c = Chat.create!(user: u, model_id: Model.first.id); m = c.messages.create!(role: "assistant", content: "x", model_id: Model.first.id, input_tokens: 5, output_tokens: 7, cost: 0.5)'
git checkout ruby-llm-2 -- db/ && git stash pop
bin/rails db:migrate
bin/rails runner 'c = Chat.last; p c.model_id, c.cost.total, c.messages.last.tokens.to_h, RubyLLM::ActiveRecord::Usage.last.model'
```

Expected: model name string, `0.5`, `{input: 5, output: 7, …}`, model name (not a UUID). (The sequence above runs the 1.x schema; do it on a scratch DB copy — `cp storage/development.sqlite3 storage/development.bak` first and restore after.)

- [ ] **Step 7: Run tests**

Run: `bin/rails db:test:prepare && bin/rails test test/models/chat_test.rb test/models/message_test.rb test/models/concerns/enableable_test.rb test/migrations`
Expected: PASS. (Other suites are red until Task 8 — expected.)

- [ ] **Step 8: Commit**

```bash
git add -A Gemfile Gemfile.lock config/initializers db app/models test/fixtures test/models test/migrations
git commit -m "feat!: upgrade ruby_llm to 2.0 (rename-mode schema, gem-owned models/tool calls/usages)"
```

---

### Task 4: Cleanup migration + drop app cost caches

**Files:**
- Create: generator cleanup migration, `db/migrate/<ts>_drop_app_cost_caches.rb`
- Modify: `app/models/user.rb`, `app/models/team.rb`, `app/models/ai_cost.rb`, `lib/tasks/counter_cache.rake`
- Delete: `app/models/concerns/costable.rb`
- Test: `test/models/user_test.rb`, `test/models/team_test.rb`

**Interfaces:**
- Produces: `Chat.with_usage_cost`, `User.with_usage_cost`, `Team.with_usage_cost` scopes (each adds a `usage_cost` decimal attribute), `User#ruby_llm_usages`, `Team#ruby_llm_usages`, `Team#total_chat_cost` (BigDecimal).

> Upstream recommends cleanup "in a later deployment". This template ships it in the same release; forks that want the safety window can delete the cleanup migration file from their merge and re-generate it later with `bin/rails g ruby_llm:upgrade --phase cleanup`. Call this out in the PR description.

- [ ] **Step 1: Failing tests** — `test/models/team_test.rb`:

```ruby
test "total chat cost sums usage costs across the team's chats" do
  assert_in_delta 0.0012, teams(:one).total_chat_cost
end

test "with_usage_cost exposes a sortable usage_cost" do
  team = Team.with_usage_cost.find(teams(:one).id)
  assert_in_delta 0.0012, team.usage_cost
end
```

`test/models/user_test.rb`:

```ruby
test "with_usage_cost exposes a sortable usage_cost" do
  assert_in_delta 0.0012, User.with_usage_cost.find(users(:one).id).usage_cost
end
```

Run: `bin/rails test test/models/team_test.rb test/models/user_test.rb` → FAIL (`undefined method with_usage_cost`).

- [ ] **Step 2: Migrations**

```bash
bin/rails g ruby_llm:upgrade --phase cleanup
bin/rails g migration DropAppCostCaches
```

```ruby
class DropAppCostCaches < ActiveRecord::Migration[8.1]
  # Cost now lives in ruby_llm_usages. Chat spend was also mirrored into ai_costs; drop it to avoid double counting.
  def up
    remove_column :chats, :total_cost
    remove_column :users, :total_cost
    remove_column :ruby_llm_models, :chats_count
    remove_column :ruby_llm_models, :total_cost
    remove_column :messages, :provider if column_exists?(:messages, :provider)
    execute "DELETE FROM ai_costs WHERE cost_type = 'chat'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

(`messages.total_cost`, `model_id`, `tool_call_id`, token columns and `content_raw` are dropped by the generator's cleanup.)

- [ ] **Step 3: Scopes and associations**

`app/models/chat.rb` add:

```ruby
  scope :with_usage_cost, -> {
    select("chats.*", "(SELECT COALESCE(SUM(u.total_cost), 0) FROM ruby_llm_usages u " \
                      "WHERE u.chat_type = 'Chat' AND u.chat_id = chats.id) AS usage_cost")
  }
```

`app/models/user.rb`: remove `include Costable` and `recalculate_total_cost!`; add

```ruby
  has_many :ruby_llm_usages, through: :chats

  scope :with_usage_cost, -> {
    select("users.*", "(SELECT COALESCE(SUM(u.total_cost), 0) FROM ruby_llm_usages u " \
                      "JOIN chats c ON u.chat_type = 'Chat' AND u.chat_id = c.id WHERE c.user_id = users.id) AS usage_cost")
  }
```

`app/models/team.rb`: add the same `has_many :ruby_llm_usages, through: :chats` and `with_usage_cost` with `WHERE c.team_id = teams.id`; replace `total_chat_cost` body with `ruby_llm_usages.sum(:total_cost)`.

`app/models/ai_cost.rb`: `COST_TYPES = %w[embedding translation moderation].freeze`. Delete `app/models/concerns/costable.rb`. `lib/tasks/counter_cache.rake`: keep only the `messages_count` rebuild.

- [ ] **Step 4: Migrate and test**

Run: `bin/rails db:migrate && bin/rails db:test:prepare && bin/rails test test/models`
Expected: `test/models` PASS except `ai_cost_test.rb` (fixed in Task 5).

- [ ] **Step 5: Commit**

```bash
git add -A db app/models lib/tasks test/models
git commit -m "refactor(costs): read chat spend from ruby_llm_usages, drop app cost caches"
```

---

### Task 5: Standalone LLM calls + AiCost + model registry call sites

**Files:**
- Modify: `app/models/ai_cost.rb`, `app/jobs/{translate_content,moderate_message,embed_record,rebuild_all_embeddings}_job.rb`, `app/models/concerns/embeddable.rb`, `app/controllers/models_controller.rb`, `app/controllers/models/refreshes_controller.rb`, `app/views/models/{index,show,_model}.html.erb`, `app/views/chats/_form.html.erb`
- Test: `test/models/ai_cost_test.rb`, `test/jobs/translate_content_job_test.rb`, `test/controllers/models_controller_test.rb` (create if absent), `test/models/concerns/embeddable_test.rb`

**Interfaces:**
- Produces: `AiCost.record_response!(cost_type:, model_id:, response:, team: nil, user: nil, trackable: nil)` — reads `response.tokens.input/.output` and `response.cost.total`.

- [ ] **Step 1: Failing tests** — rewrite `test/models/ai_cost_test.rb` cost-calculation tests:

```ruby
Response = Data.define(:tokens, :cost)

def response(input:, output: 0, total:)
  tokens = RubyLLM::Tokens.new(input: input, output: output)
  Response.new(tokens: tokens, cost: RubyLLM::Cost.from_h({ total: total }, tokens: tokens))
end

test "record_response! stores tokens and the gem-computed cost" do
  cost = AiCost.record_response!(cost_type: "translation", model_id: "gpt-4", response: response(input: 500, output: 200, total: 0.027))
  assert_equal 500, cost.input_tokens
  assert_equal 200, cost.output_tokens
  assert_in_delta 0.027, cost.cost
end

test "record_response! stores zero when the model has no price" do
  cost = AiCost.record_response!(cost_type: "embedding", model_id: "x", response: response(input: 1, total: nil))
  assert_equal 0, cost.cost
end

test "chat is no longer a cost type" do
  assert_not AiCost.new(cost_type: "chat", model_id: "gpt-4").valid?
end
```

Update `test/jobs/translate_content_job_test.rb:4-6`:

```ruby
MockResponse = Data.define(:content, :tokens, :cost) do
  def initialize(content:, tokens: RubyLLM::Tokens.new(input: 0, output: 0), cost: nil)
    super(content:, tokens:, cost: cost || RubyLLM::Cost.from_h({ total: 0 }, tokens:))
  end
end
```

Run: `bin/rails test test/models/ai_cost_test.rb test/jobs/translate_content_job_test.rb` → FAIL.

- [ ] **Step 2: Implement AiCost**

Remove `before_save :calculate_cost` and `calculate_cost`, `formatted_cost`, and `record!`. Add:

```ruby
  def self.record_response!(cost_type:, model_id:, response:, team: nil, user: nil, trackable: nil)
    create!(
      cost_type:, model_id:, team:, user:, trackable:,
      input_tokens: response.tokens.input.to_i,
      output_tokens: response.tokens.output.to_i,
      cost: response.cost&.total.to_d,
    )
  end
```

- [ ] **Step 3: Call sites**

- `translate_content_job.rb` `record_cost` → `AiCost.record_response!(cost_type: "translation", model_id: model, response:, team: record.try(:team), user: record.try(:user), trackable: record)`.
- `moderate_message_job.rb` `record_cost` → same with `cost_type: "moderation"` and its existing team/user/trackable.
- `embed_record_job.rb:29-38` and `embeddable.rb:97-102` → `AiCost.record_response!(cost_type: "embedding", model_id: model, response:, …)` keeping existing team/user/trackable args.
- `rebuild_all_embeddings_job.rb:7-8` → `dimensions = RubyLLM::ActiveRecord::Model.find_by(model_id: Setting.embedding_model)&.max_output_tokens`.
- `models_controller.rb` → `@models = RubyLLM::ActiveRecord::Model.enabled.order(:provider, :name)`; `show` → `RubyLLM::ActiveRecord::Model.enabled.find(params[:id])`.
- `models/refreshes_controller.rb:5` → `RubyLLM.models.refresh`.
- `app/views/models/_model.html.erb` → replace `model.pricing['text_tokens']['standard']['input_per_million']` / `output…` with `model.price(:input)` / `model.price(:output)`; `team_model_path(current_team, model)` stays (`to_param` is the id). `show.html.erb` unchanged apart from any removed attribute.
- `app/views/chats/_form.html.erb:14-17` →

```erb
<% default_model = RubyLLM::ActiveRecord::Model.find_by(model_id: RubyLLM.config.default_model) %>
…
<%= … RubyLLM::ActiveRecord::Model.enabled.order(:name).map { |m| [m.name, m.model_id] } … %>
```

(Move both queries into `ChatsController#new` as `@default_model` / `@model_options` — views must not query, `.claude/rules/views.md`.)

- [ ] **Step 4: Review Focus #5 test** — `test/controllers/models/refreshes_controller_test.rb`:

```ruby
test "refresh keeps the default model selectable" do
  sign_in users(:one)
  RubyLLM.models.stub(:refresh, nil) do
    post team_models_refresh_path(teams(:one).slug)
  end
  assert_redirected_to team_models_path(teams(:one).slug)
  get new_team_chat_path(teams(:one).slug)
  assert_response :success
end
```

- [ ] **Step 5: Run**

Run: `bin/rails test test/models test/jobs test/controllers/models* test/controllers/chats_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A app test
git commit -m "refactor(ai): read tokens/cost from RubyLLM 2.0 responses and registry"
```

---

### Task 6: Chat flow + MCP tools and resources

**Files:**
- Modify: `app/controllers/chats_controller.rb`, `app/jobs/chat_response_job.rb`, `app/views/chats/{_chat,index}.html.erb`, `app/views/messages/{_form,_message,_tool_calls}.html.erb`, `app/tools/models/{list_models,show_model}_tool.rb`, `app/tools/chats/{create_chat,update_chat,list_chats,show_chat}_tool.rb`, `app/tools/messages/{create_message,list_messages}_tool.rb`, `app/tools/users/show_current_user_tool.rb`, `app/tools/teams/show_team_tool.rb`, `app/resources/mcp/available_models_resource.rb`
- Test: matching files under `test/tools/`, `test/resources/available_models_resource_test.rb`, `test/jobs/chat_response_job_test.rb` (create)

**Interfaces:**
- Consumes: Task 3 `Chat`/`Message` API; Task 4 `with_usage_cost`.
- Produces: MCP `create_chat` / `update_chat` accept `model_id` as either the registry model name (`"gpt-4"`) or the registry row id; serialized chat/message payload shape:
  - chat: `{ id, model_id: <name>, model_name, messages_count, total_cost: Float, created_at, … }`
  - message: `{ id, role, content, model_id: <name|nil>, input_tokens, output_tokens, cost: Float|nil, created_at }`

- [ ] **Step 1: Failing tests**

`test/tools/chats/create_chat_tool_test.rb` — change the model argument and assertions:

```ruby
test "accepts a model name" do
  result = call_tool(Chats::CreateChatTool, model_id: "gpt-4")
  assert result[:success]
  assert_equal "gpt-4", result[:data][:model_id]
end

test "accepts a registry id" do
  result = call_tool(Chats::CreateChatTool, model_id: ruby_llm_models(:gpt4).id)
  assert_equal "gpt-4", result[:data][:model_id]
end
```

(Keep the file's existing `call_tool`/auth helper names; replace `models(:…)` with `ruby_llm_models(:…)` and `Model.enabled` with `RubyLLM::ActiveRecord::Model.enabled` everywhere under `test/tools` and `test/resources`.)

`test/tools/chats/show_chat_tool_test.rb` add:

```ruby
test "serializes tokens and cost from usages" do
  message = call_tool(Chats::ShowChatTool, chat_id: chats(:one).id)[:data][:messages].find { |m| m[:role] == "assistant" }
  assert_equal 10, message[:input_tokens]
  assert_equal 15, message[:output_tokens]
  assert_in_delta 0.0012, message[:cost]
end

test "a chat whose only usage has no price reports zero total cost" do
  RubyLLM::ActiveRecord::Usage.update_all(total_cost: nil)
  assert_equal 0.0, call_tool(Chats::ShowChatTool, chat_id: chats(:one).id)[:data][:total_cost]
end
```

`test/jobs/chat_response_job_test.rb`:

```ruby
require "test_helper"

class ChatResponseJobTest < ActiveJob::TestCase
  test "streams chunks into the assistant placeholder" do
    chat = chats(:one)
    placeholder = chat.messages.create!(role: "assistant", content: "")
    appended = []
    fake_ask = ->(*, **, &block) { block.call(RubyLLM::Chunk.new(role: :assistant, content: "Hi")) }

    Message.stub_any_instance(:broadcast_append_chunk, ->(c) { appended << c }) do
      chat.stub(:ask, fake_ask) { Chat.stub(:find, chat) { ChatResponseJob.perform_now(chat.id, "Hello") } }
    end

    assert_equal [ "Hi" ], appended
  end
end
```

(If `stub_any_instance` isn't available in the suite, stub `Message#broadcast_append_chunk` via `placeholder.define_singleton_method` and `chat.messages.stub(:where, …)`; match whatever stubbing style `test/jobs/*` already uses.)

Run the files above → FAIL.

- [ ] **Step 2: Implement**

`app/jobs/chat_response_job.rb` streaming block:

```ruby
    placeholder = nil
    chat.ask(content, **ask_options) do |chunk|
      next if chunk.content.blank?

      placeholder ||= chat.messages.where(role: "assistant").last
      placeholder.broadcast_append_chunk(chunk.content)
    end
```

`app/controllers/chats_controller.rb`:
- `index`: `.includes(:model, :messages)` stays (`:model` is now the gem association).
- `set_chat`: `.includes(messages: [ :ruby_llm_tool_calls, :ruby_llm_usages, { attachments_attachments: :blob } ])`.
- `create`: unchanged — `create!(model: "<name>")` is supported by `acts_as_chat`.

Views:
- `chats/_chat.html.erb:4`, `chats/index.html.erb:27`, `messages/_form.html.erb:15`: `chat.model&.name` is unchanged (still valid).
- `messages/_message.html.erb:50-51`: `message.tool_call?` → `message.tool_calls.present?`.
- `messages/_tool_calls.html.erb`: `message.tool_calls.each do |tool_call|` → `message.tool_calls.each_value do |tool_call|`; `tool_call.arguments` stays.

MCP (shared serialization):
- `Chats::ListChatsTool` — `chats = …includes(:model).with_usage_cost`; `total_cost: chat.usage_cost.to_f`; `model_id: chat.model_id` (now the name).
- `Chats::ShowChatTool` / `Messages::CreateMessageTool` / `Messages::ListMessagesTool` — load messages with `.includes(:ruby_llm_usages)`; per message:

```ruby
        model_id: message.model,
        input_tokens: message.tokens.input,
        output_tokens: message.tokens.output,
        cost: message.cost.total&.to_f,
```

  chat total: `total_cost: chat.ruby_llm_usages.sum(:total_cost).to_f`.
- `Chats::CreateChatTool` / `Chats::UpdateChatTool` — lookup:

```ruby
      models = RubyLLM::ActiveRecord::Model.enabled
      model = models.find_by(model_id: model_id) || models.find_by(id: model_id)
```

  create: `current_user.chats.create!(model: model.model_id, provider: model.provider, team: current_team)`; update: `chat.with_model(model.model_id, provider: model.provider)`. Update argument description to "Model name (e.g. from list_models `model_id`) or registry id".
- `Models::ListModelsTool` / `Models::ShowModelTool` / `Mcp::AvailableModelsResource` — `Model` → `RubyLLM::ActiveRecord::Model`; `Model.configured_providers` → `ProviderCredential.configured_providers`; drop `chats_count` / `total_cost` from serialization; `pricing` → `{ input_per_million: model.price(:input), output_per_million: model.price(:output) }`.
- `Users::ShowCurrentUserTool:32` → `total_cost: user.ruby_llm_usages.sum(:total_cost).to_f`. `Teams::ShowTeamTool:36` unchanged (`total_chat_cost` reimplemented in Task 4).

- [ ] **Step 3: Run**

Run: `bin/rails test test/tools test/resources test/jobs test/controllers/chats_controller_test.rb`
Expected: PASS.

- [ ] **Step 4: Manual smoke** — `bin/dev`, sign in, start a chat on the default model, confirm streaming renders and the reply persists with a cost in Madmin (Task 7). OpenAI now uses the Responses API by default; if the configured default model rejects it, record the error and set `config.openai_protocol = :chat_completions` in `config/initializers/ruby_llm.rb` with a comment explaining why.

- [ ] **Step 5: Commit**

```bash
git add -A app test
git commit -m "refactor(chat): stream and serialize chats on the RubyLLM 2.0 API"
```

---

### Task 7: Madmin

**Files:**
- Modify: `app/madmin/resources/{model,tool_call,chat,message,team,user}_resource.rb`, `app/controllers/madmin/{ai_models,models,chats,messages,teams,users,tool_calls,dashboard}_controller.rb`, `app/views/madmin/{models,ai_models,chats,messages,users,teams,tool_calls,dashboard}/*.html.erb`, `app/views/madmin/application/_sidebar.html.erb`
- Test: `test/integration/madmin_resources_test.rb`, `test/controllers/madmin/dashboard_controller_test.rb`

**Interfaces:**
- Consumes: `with_usage_cost` scopes (Task 4), `Enableable` (Task 3).

- [ ] **Step 1: Failing tests** — in `test/integration/madmin_resources_test.rb` replace `models(:gpt4)` → `ruby_llm_models(:gpt4)`, `tool_calls(:search_call)` → `ruby_llm_tool_calls(:search_call)`, drop the `if Model.exists?` guard, and add sorting coverage:

```ruby
%w[chats users teams models].each do |resource|
  test "#{resource} index sorts by cost" do
    get "/madmin/#{resource}", params: { sort: "usage_cost", direction: "desc" }
    assert_response :success
  end
end

test "chat show renders tokens and cost from usages" do
  get madmin_chat_path(chats(:one))
  assert_response :success
  assert_includes response.body, "$0.0012"
end
```

Run: `bin/rails test test/integration/madmin_resources_test.rb test/controllers/madmin` → FAIL.

- [ ] **Step 2: Resources bound to gem classes**

`app/madmin/resources/model_resource.rb` top:

```ruby
class ModelResource < Madmin::Resource
  model RubyLLM::ActiveRecord::Model

  def self.index_path(options = {}) = Rails.application.routes.url_helpers.madmin_models_path(options)
  def self.show_path(record) = Rails.application.routes.url_helpers.madmin_model_path(record)
```

Remove `attribute :provider … collection` hard-coded provider list → `attribute :provider`; add `attribute :unlisted_at, form: false`. `sortable_columns` → `super + %w[chats_count usage_cost]`.

`app/madmin/resources/tool_call_resource.rb`: `model RubyLLM::ActiveRecord::ToolCall` + the same two path overrides with `madmin_tool_calls_path` / `madmin_tool_call_path`; add `attribute :approval`, `attribute :result`. Check `new_path`/`edit_path` are not reachable (resource is index/show only) — if Madmin still calls them, override them too.

`message_resource.rb`: remove `model`, token and `cost` attributes; `tool_calls` → `ruby_llm_tool_calls`; add `attribute :ruby_llm_usages, form: false`. `chat_resource.rb`: keep `model` (still an association). `team_resource.rb` / `user_resource.rb`: `sortable_columns` swap `total_cost` → `usage_cost`.

- [ ] **Step 3: Controllers**

- `madmin/models_controller.rb`: `super.enabled` → keep (scope from `Enableable`); add

```ruby
    resources = resources.select(
      "ruby_llm_models.*",
      "(SELECT COUNT(*) FROM chats WHERE chats.ruby_llm_model_id = ruby_llm_models.id) AS chats_count",
      "(SELECT COALESCE(SUM(u.total_cost), 0) FROM ruby_llm_usages u " \
      "WHERE u.provider = ruby_llm_models.provider AND u.model = ruby_llm_models.model_id) AS usage_cost"
    )
    resources = resources.reorder(Arel.sql("#{sort_column} #{sort_direction}")) if %w[chats_count usage_cost].include?(sort_column)
```

  `refresh_all`: `Model.refresh!` → `RubyLLM.models.refresh`; `Model.count` → `RubyLLM::ActiveRecord::Model.listed.count`.
- `madmin/ai_models_controller.rb`: every `Model.` → `RubyLLM::ActiveRecord::Model.`; `refresh_all` as above; in `load_models_table` apply the same `select` as the models controller so `chats_count`/`usage_cost` render.
- `madmin/chats_controller.rb`: `super.includes(:user, :model, :messages).with_usage_cost`; custom sort `when "usage_cost" then resources.reorder(Arel.sql("usage_cost #{sort_direction}"))`.
- `madmin/messages_controller.rb`: `includes(:model, :tool_calls, chat: :messages)` → `includes(:ruby_llm_tool_calls, :ruby_llm_usages, chat: :messages)`.
- `madmin/teams_controller.rb:35-39` → `when "usage_cost" then resources.with_usage_cost.reorder(Arel.sql("usage_cost #{dir}"))`; apply `.with_usage_cost` in the default branch too so the column renders.
- `madmin/users_controller.rb`: same `usage_cost` branch + default `.with_usage_cost`.
- `madmin/tool_calls_controller.rb`: `super.includes(:message)` stays (polymorphic).
- `madmin/dashboard_controller.rb`:
  - `total_tokens`: `Chat.joins(:ruby_llm_usages).sum("COALESCE(ruby_llm_usages.input_tokens,0) + COALESCE(ruby_llm_usages.output_tokens,0) + COALESCE(ruby_llm_usages.cache_read_tokens,0) + COALESCE(ruby_llm_usages.cache_write_tokens,0)")`
  - `total_cost`: `AiCost.sum(:cost) + Chat.joins(:ruby_llm_usages).sum("ruby_llm_usages.total_cost")`
  - `total_tool_calls`: remove (unrendered).
  - `total_models`: `RubyLLM::ActiveRecord::Model.enabled.count`
  - `@recent_chats`: `Chat.includes(:user, :model, :messages).with_usage_cost…`
  - `@top_teams` / `@top_users`: replace `SUM(chats.total_cost) AS ai_total_cost` with the correlated subquery from `Team.with_usage_cost` / `User.with_usage_cost` aliased `ai_total_cost`, and `.order(Arel.sql("ai_total_cost DESC"))`.
  - `@cost_timeline`: add a `"chat"` series: `Chat.joins(:ruby_llm_usages).where(ruby_llm_usages: { created_at: @range }).group_by_day("ruby_llm_usages.created_at", range: @range).sum("ruby_llm_usages.total_cost")`, merged into the existing per-type hash so the chart keeps its chat line. Wrap in `cached_dashboard`.

- [ ] **Step 4: Views**

- `madmin/chats/index`: `sortable :total_cost` → `sortable :usage_cost`; cell `format_cost(record.usage_cost, precision: 4)`.
- `madmin/chats/show:40-45,101-102`: tokens `@record.messages.sum { |m| m.tokens.input.to_i }` / `.output`; total `format_cost(@record.ruby_llm_usages.sum(&:total_cost).to_d, precision: 4)` (preload `ruby_llm_usages` via `messages: :ruby_llm_usages` in the controller's `show` scope); per message `if (cost = message.cost.total)&.positive?`.
- `madmin/messages/index:49,72`: `sortable :cost` → remove column **and** header (no stored column to sort by; `.claude/rules/madmin.md` forbids unsortable columns). `madmin/messages/show:39-48`: `@record.tokens.input` / `.output`; `format_cost(@record.cost.total || 0, precision: 4)`; tool calls `@record.tool_calls.each_value`.
- `madmin/users/index:40,78` + `show:37-40,131-147`: `total_cost` → `usage_cost`; per-chat cost uses `Chat.with_usage_cost` (load in controller `show` as `@chats = @record.chats.includes(:model).with_usage_cost`).
- `madmin/teams/index:31,62-65` + `show:42,56-60,178-206`: same pattern; delete the `record.chats.sum(&:total_cost)` Ruby sums.
- `madmin/models/index:28,51-52,70-71` + `show:43-49`: `Model.distinct…` → `RubyLLM::ActiveRecord::Model.distinct…` (move into controller as `@providers`); `total_cost` → `usage_cost`; show page computes both via the same `select` in `set_record` (override `set_record` or compute in view-free controller ivars).
- `madmin/ai_models/show:129-130,143,147-148`: `model.total_cost` → `model.usage_cost`.
- `madmin/tool_calls/index:52,55` + `show`: `record.message&.content` works (polymorphic); `respond_to?(:result)` → `@record.result&.content`.
- `madmin/dashboard/show:179-185`: `chat.total_cost` → `chat.usage_cost`.
- `_sidebar.html.erb:15-16`: `Model.count` → `RubyLLM::ActiveRecord::Model.listed.count`; `ToolCall.count` → `RubyLLM::ActiveRecord::ToolCall.count`.

- [ ] **Step 5: Run**

Run: `bin/rails test test/integration test/controllers/madmin`
Expected: PASS. Then `bin/dev`, sign in as admin, click through `/madmin`, `/madmin/chats`, `/madmin/messages`, `/madmin/tool_calls`, `/madmin/models`, `/madmin/ai_models`, `/madmin/teams`, `/madmin/users` sorting each column once.

- [ ] **Step 6: Commit**

```bash
git add -A app test
git commit -m "refactor(madmin): read models, tool calls and costs from RubyLLM 2.0 tables"
```

---

### Task 8: i18n, docs, full gate

**Files:**
- Modify: `config/locales/{en,ru}/activerecord.yml`, `config/locales/{en,ru}/views/madmin/{messages,chats,users,teams,models,ai_models,dashboard}.yml`, `AGENTS.md`, `README.md`
- Test: `bundle exec i18n-tasks health`, `bin/ci`

- [ ] **Step 1: i18n** — run `bundle exec i18n-tasks unused` and `missing`. Remove keys for deleted columns (`messages.index.col_cost`, …); rename `col_total_cost`/`total_cost` keys only where the label text changes; add `activerecord.models.ruby_llm/active_record/model` and `…/tool_call` in en + ru if Madmin titles fall back to them. Re-run until `bundle exec i18n-tasks health` is clean.

- [ ] **Step 2: Docs** — `AGENTS.md`:
  - "RubyLLM AI Chat" block → `Chat → belongs_to :user, :team; acts_as_chat (model: RubyLLM::ActiveRecord::Model via ruby_llm_model_id)`, `Message → acts_as_message (tokens/cost via ruby_llm_usages)`, drop the `Model →` line.
  - Dashboards "Caching" example `SUM(chats.total_cost)` → `Team.with_usage_cost.order(Arel.sql("usage_cost DESC"))`.
  - Add a short "Costs" note: chat spend = `ruby_llm_usages` (`chat.cost`, `with_usage_cost`); non-chat spend (translation/embedding/moderation) = `AiCost.record_response!`.
  - `.claude/rules/performance.md` example with `SUM(chats.total_cost)` → same replacement.

- [ ] **Step 3: Full gate**

Run: `bin/ci`
Expected: rubocop, tests, brakeman, i18n-tasks all PASS.

- [ ] **Step 4: Commit**

```bash
git add -A config/locales AGENTS.md README.md .claude/rules/performance.md
git commit -m "docs: document RubyLLM 2.0 models, usages and cost sources"
```

---

### Task 9: `ruby_llm:upgrade_check` + UPGRADING.md

Downstream apps upgrade by merging the template, running this check, fixing what it lists, then `bin/rails db:migrate`. The check must work **before** migrating (legacy tables present) and **after** (should report nothing).

**Files:**
- Create: `lib/ruby_llm_upgrade_check.rb`, `lib/tasks/ruby_llm_upgrade.rake`, `test/lib/ruby_llm_upgrade_check_test.rb`, `UPGRADING.md`
- Modify: `AGENTS.md` (one line under Quick Reference)

**Interfaces:**
- Produces:
  - `RubyLlmUpgradeCheck.new(root: Rails.root, connection: ActiveRecord::Base.connection)`
  - `#code_findings → Array<RubyLlmUpgradeCheck::Finding>`; `Finding = Data.define(:path, :line, :code, :fix, :severity)` with `severity` in `:blocker | :review`
  - `#data_findings → Array<Finding>` (path = table name, line = nil)
  - `#report → String`, `#blockers? → Boolean`
  - `bin/rails ruby_llm:upgrade_check` prints the report; exits 1 when `blockers?`.

- [ ] **Step 1: Failing tests** — `test/lib/ruby_llm_upgrade_check_test.rb`:

```ruby
require "test_helper"
require "ruby_llm_upgrade_check"

class RubyLlmUpgradeCheckTest < ActiveSupport::TestCase
  setup { @root = Pathname(Dir.mktmpdir) }
  teardown { FileUtils.rm_rf(@root) }

  def write(path, body)
    (@root / path).dirname.mkpath
    (@root / path).write(body)
  end

  def check = RubyLlmUpgradeCheck.new(root: @root, connection: ActiveRecord::Base.connection)

  test "flags removed chat APIs with their replacement" do
    write "app/models/concerns/summaries.rb", <<~RUBY
      chat = RubyLLM.chat(model: m).with_params(store: false)
      provider = RubyLLM::Models.find(model_id).provider
    RUBY

    codes = check.code_findings.map { |f| [ f.path, f.line, f.fix ] }
    assert_includes codes, [ "app/models/concerns/summaries.rb", 1, "with_provider_options(...)" ]
    assert_includes codes, [ "app/models/concerns/summaries.rb", 2, "RubyLLM.models.find(id, provider: ...)" ]
  end

  test "flags references to the deleted app Model class but not the gem class" do
    write "app/models/post.rb", "Model.resolve(id)\nRubyLLM::ActiveRecord::Model.enabled\n"
    assert_equal [ 1 ], check.code_findings.map(&:line)
  end

  test "flags RubyLLM error constants that no longer exist" do
    write "app/jobs/a_job.rb", "retry_on RubyLLM::RateLimitError, RubyLLM::NoSuchThingError\n"
    assert_equal [ "RubyLLM::NoSuchThingError" ], check.code_findings.map(&:code)
  end

  test "ignores db/, vendor/ and test fixtures" do
    write "db/migrate/1_x.rb", "Model.find_by(1)\n"
    write "vendor/x.rb", "with_params(a: 1)\n"
    assert_empty check.code_findings
  end

  test "is clean on the upgraded template itself" do
    report = RubyLlmUpgradeCheck.new(root: Rails.root, connection: ActiveRecord::Base.connection)
    assert_empty report.code_findings.select { _1.severity == :blocker }, report.report
    assert_empty report.data_findings, report.report
  end
end
```

Run: `bin/rails test test/lib/ruby_llm_upgrade_check_test.rb` → FAIL (`cannot load such file -- ruby_llm_upgrade_check`).

- [ ] **Step 2: Implement** — `lib/ruby_llm_upgrade_check.rb`:

```ruby
# Scans an app for RubyLLM 1.x APIs removed in 2.0 and for data that would stop the upgrade migrations.
# Run with `bin/rails ruby_llm:upgrade_check` after merging the template, before `db:migrate`.
class RubyLlmUpgradeCheck
  Finding = Data.define(:path, :line, :code, :fix, :severity)
  Rule = Data.define(:pattern, :fix, :severity)

  SCAN_GLOBS = %w[app/**/*.{rb,erb} lib/**/*.{rb,rake} config/**/*.rb].freeze
  SKIP = %r{\A(db|vendor|test|spec|node_modules)/|\Alib/ruby_llm_upgrade_check\.rb\z}

  RULES = [
    Rule.new(/(?<!::)(?<![\w.])Model\.\w+/, "RubyLLM::ActiveRecord::Model.* (app Model class removed)", :blocker),
    Rule.new(/(?<!::)\bToolCall\b/, "RubyLLM::ActiveRecord::ToolCall / message.tool_calls (app ToolCall removed)", :blocker),
    Rule.new(/\bacts_as_(model|tool_call)\b/, "delete the declaration and the class", :blocker),
    Rule.new(/\b(tool_calls_foreign_key|chats_foreign_key|model_registry_class|use_new_acts_as)\b/, "remove option", :blocker),
    Rule.new(/\bwith_params\(/, "with_provider_options(...)", :blocker),
    Rule.new(/\bparams:\s/, "provider_options: (if passed to RubyLLM)", :review),
    Rule.new(/\bresponse_format\b/, "OpenAI now uses the Responses API: text: { format: ... }, or config.openai_protocol = :chat_completions", :review),
    Rule.new(/\bwith_tool\(/, "with_tools(...)", :blocker),
    Rule.new(/\bwith_tools\([^)]*\b(choice|calls):/, "with_tools(...).with_tool_options(choice:, calls:)", :blocker),
    Rule.new(/\bon_new_message\b/, "before_message", :blocker),
    Rule.new(/\bon_end_message\b/, "after_message", :blocker),
    Rule.new(/\bon_tool_call\b/, "before_tool_call", :blocker),
    Rule.new(/\bon_tool_result\b/, "after_tool_result", :blocker),
    Rule.new(/\bcreate_user_message\b/, "add_message(role: :user, content:) or ask_later", :blocker),
    Rule.new(/\breset_messages!/, "chat.messages = []", :blocker),
    Rule.new(/\bassume_exists:/, "assume_model_exists:", :blocker),
    Rule.new(/\bwith_instructions\([^)]*replace:/, "with_instructions replaces by default; append: true to add", :blocker),
    Rule.new(/\bRubyLLM::Models\.find\b|\bRubyLLM\.models\.find\([^)]*,\s*:/, "RubyLLM.models.find(id, provider: ...)", :blocker),
    Rule.new(/\bRubyLLM\.models\.(refresh|load_from_database|load_from_json)!/, "RubyLLM.models.refresh / load_from_store / load_from_json", :blocker),
    Rule.new(/\bRubyLLM::Tokens\.build\b/, "RubyLLM::Tokens.new(...)", :blocker),
    Rule.new(/\bRubyLLM::Cost\.new\b/, "response.cost / message.cost (RubyLLM::Cost), or RubyLLM::Cost.from_h", :review),
    Rule.new(/\bRubyLLM::Schema\b/, "Schematist::Schema", :blocker),
    Rule.new(/\bRubyLLM::Model::Info\b/, "RubyLLM::Model", :blocker),
    Rule.new(/\bfrom_llm_attributes\b/, "removed; registry rows are written by RubyLLM::ActiveRecord::Model.save_to_database (custom columns are not refreshed)", :blocker),
    Rule.new(/\.(input|output|cached|cache_creation|reasoning)_tokens\b/, "response.tokens.input/.output/.cache_read/.cache_write/.thinking (message token columns moved to ruby_llm_usages)", :review),
    Rule.new(/\b(display_name|max_tokens|input_price_per_million|output_price_per_million|cached_input_price_per_million)\b/, "model.name / max_output_tokens / price(:input|:output|:cache_read)", :review),
    Rule.new(/\bsupports_(vision|functions|json_mode)\?/, "supports?(:vision | :function_calling | :structured_output)", :blocker),
    Rule.new(/\bfinish_reason\b/, "now a Symbol (:stop, :max_tokens, :tool_calls, :content_filter)", :review),
    Rule.new(/\b(desc|param|params_schema|provider_params)\s/, "Tool DSL: description / parameter / parameters_schema / provider_options", :review),
    Rule.new(/\bhalt\(/, "tools no longer halt; loop chat.step or use requires_approval", :review),
    Rule.new(/\btotal_cost\b|\bmessage\.cost\b/, "cost columns dropped: chat.cost / message.cost (RubyLLM::Cost#total) or .with_usage_cost", :review),
  ].freeze

  def initialize(root:, connection:)
    @root = Pathname(root)
    @connection = connection
  end

  def code_findings
    @code_findings ||= source_files.flat_map { |path| scan(path) }
  end

  def data_findings
    return [] unless @connection.table_exists?(:models) && @connection.column_exists?(:chats, :model_id)

    [
      count_finding(:chats, "chats.model_id pointing at a missing model",
        "SELECT COUNT(*) FROM chats WHERE model_id IS NOT NULL AND model_id NOT IN (SELECT id FROM models)"),
      count_finding(:tool_calls, "tool_calls without tool_call_id",
        "SELECT COUNT(*) FROM tool_calls WHERE tool_call_id IS NULL"),
      count_finding(:messages, "tool calls answered by more than one message",
        "SELECT COUNT(*) FROM (SELECT tool_call_id FROM messages WHERE tool_call_id IS NOT NULL GROUP BY tool_call_id HAVING COUNT(*) > 1)"),
    ].compact
  end

  def blockers? = (code_findings + data_findings).any? { _1.severity == :blocker }

  def report
    findings = code_findings + data_findings
    return "RubyLLM 2.0 upgrade check: nothing to fix." if findings.empty?

    lines = findings.sort_by { [ _1.severity == :blocker ? 0 : 1, _1.path, _1.line.to_i ] }.map do |f|
      "[#{f.severity}] #{[ f.path, f.line ].compact.join(':')}  #{f.code}\n          → #{f.fix}"
    end
    "RubyLLM 2.0 upgrade check: #{findings.count} finding(s)\n\n#{lines.join("\n")}"
  end

  private

  def source_files
    SCAN_GLOBS.flat_map { Dir.glob(_1, base: @root) }.uniq.reject { _1.match?(SKIP) }.sort
  end

  def scan(path)
    (@root / path).each_line.with_index(1).flat_map do |text, line|
      next [] if text.lstrip.start_with?("#")

      rule_findings(path, line, text) + error_constant_findings(path, line, text)
    end
  end

  def rule_findings(path, line, text)
    RULES.filter_map do |rule|
      match = text[rule.pattern] or next
      Finding.new(path:, line:, code: match, fix: rule.fix, severity: rule.severity)
    end
  end

  def error_constant_findings(path, line, text)
    text.scan(/RubyLLM::\w*Error\b/).reject { RubyLLM.const_defined?(_1.delete_prefix("RubyLLM::")) }.map do |const|
      Finding.new(path:, line:, code: const, fix: "error class no longer exists in RubyLLM 2.0", severity: :blocker)
    end
  end

  def count_finding(table, label, sql)
    count = @connection.select_value(sql).to_i
    return if count.zero?

    Finding.new(path: table.to_s, line: nil, code: "#{count} #{label}", fix: "repair before db:migrate", severity: :blocker)
  end
end
```

`lib/tasks/ruby_llm_upgrade.rake`:

```ruby
namespace :ruby_llm do
  desc "List code and data that must change before upgrading to RubyLLM 2.0 (safe to run any time)"
  task upgrade_check: :environment do
    require "ruby_llm_upgrade_check"

    check = RubyLlmUpgradeCheck.new(root: Rails.root, connection: ActiveRecord::Base.connection)
    puts check.report
    exit 1 if check.blockers?
  end
end
```

Tune `RULES` until the "clean on the upgraded template" test passes — every template hit must be either fixed code (a real miss from Tasks 3–7) or a pattern that is too broad (narrow it; don't add path exceptions).

- [ ] **Step 3: UPGRADING.md** — one page:
  1. *Who*: apps forked from this template on ruby_llm 1.9–1.16 (schema from `upgrade_to_v1_14` onward).
  2. *Steps*: `git checkout -b ruby-llm-2` → `git fetch template && git merge template/main` → `bundle install` → back up the DB (`cp storage/<env>.sqlite3 …`; production: confirm a fresh Litestream snapshot) → `bin/rails ruby_llm:upgrade_check` → fix everything listed → `bin/rails db:migrate` → `bin/rails ruby_llm:upgrade_check` (expect "nothing to fix") → `bin/ci`.
  3. *API table*: the 1.x → 2.0 renames from the check's `RULES`, grouped (chat, tokens/cost, models, tools, config).
  4. *Data*: what the migrations do (rename `models`→`ruby_llm_models`, `tool_calls`→`ruby_llm_tool_calls`, message tokens/cost → `ruby_llm_usages`, drop app cost caches) and that they are **irreversible** — restore from backup to roll back.
  5. *Custom columns*: extra columns on `chats`/`messages` are kept; extra columns on `models` are kept but **not** refreshed by `RubyLLM.models.refresh`.
  6. *Future note*: the generated migrations `require` ruby_llm generator internals; a fresh environment should use `db:schema:load` / `db:prepare`, not replay migrations.

`AGENTS.md` Quick Reference: add `bin/rails ruby_llm:upgrade_check    # RubyLLM 2.0 upgrade readiness`.

- [ ] **Step 4: Run**

Run: `bin/rails test test/lib/ruby_llm_upgrade_check_test.rb && bin/rails ruby_llm:upgrade_check`
Expected: tests PASS; task prints "nothing to fix." and exits 0.

- [ ] **Step 5: Rehearse on `main`'s code** — prove the check catches the real 1.x code:

```bash
git worktree add ../template-main-check main
cp lib/ruby_llm_upgrade_check.rb ../template-main-check/lib/ && cp lib/tasks/ruby_llm_upgrade.rake ../template-main-check/lib/tasks/
(cd ../template-main-check && bundle install && bin/rails ruby_llm:upgrade_check); echo "exit: $?"
git worktree remove --force ../template-main-check
```

Expected: exit 1 with findings including `app/models/model.rb` (`acts_as_model`), `app/models/message.rb` (`tool_calls_foreign_key`), `app/jobs/translate_content_job.rb` (`.input_tokens`), `app/controllers/models/refreshes_controller.rb` (`Model.refresh!`). If any of those is missing, add/fix the rule and a test for it. (Note: on 1.16 `RubyLLM.const_defined?` checks 1.16 constants — acceptable, error-class drift is only verified after `bundle install` on 2.0.)

- [ ] **Step 6: Commit**

```bash
git add lib/ruby_llm_upgrade_check.rb lib/tasks/ruby_llm_upgrade.rake test/lib/ruby_llm_upgrade_check_test.rb UPGRADING.md AGENTS.md
git commit -m "feat: add ruby_llm:upgrade_check and RubyLLM 2.0 upgrade guide for forks"
```

---

## Downstream Rollout (after the template branch is green and reviewed)

One app at a time, each on its own `ruby-llm-2` branch, nothing pushed without the user's go-ahead. Per app:

```bash
cd <app>
git status --short                     # dirty tree → STOP and ask the user (don't stash their work)
git checkout -b ruby-llm-2
git fetch template && git merge template/ruby-llm-2     # template branch until it lands on main
bundle install
cp storage/development.sqlite3 storage/development.pre-ruby-llm-2.sqlite3
bin/rails ruby_llm:upgrade_check       # fix every finding (project code), re-run until clean of blockers
bin/rails db:migrate
bin/rails ruby_llm:upgrade_check       # expect "nothing to fix."
bin/ci
```

Order and known work (from the 2026-09-23 survey; re-verify, it was read-only and without fetch):

1. **listen_with_me** — ruby_llm 1.11, Gemfile `~> 1.9`; dirty tree (`.ruby-version`, `Gemfile.lock`) → ask first. Merge-base Feb 2026: brings older template migrations too (`ai_costs`, `chats.first_user_message_preview`, user columns). Project code: `app/models/concerns/summaries.rb` (`with_params` → `with_provider_options`, `RubyLLM::Models.find` → `RubyLLM.models.find(…, provider:)`, `ModelNotFoundError` — verify still in `RubyLLM`), `retry_on RubyLLM::*Error` in `generate_review_job.rb` / `translate_summary_job.rb`; `chat.rb` `counter_cache: :chats_count` (column dropped) and `update_chat_tool.rb` manual `chats_count` counters. Dev DB empty.
2. **money_cast** — already 1.16, template-shaped schema. `insights_controller.rb` (`with_params(store: false, response_format: json_object)` → Responses API `text: { format: { type: "json_object" } }` via `with_provider_options`, or set `openai_protocol = :chat_completions`; `response.input_tokens`; `Model.find_by`), `generate_knowledge_doc_job.rb`, `usage_event.rb` token reads; its `message.cost&.total` edits in tools/Madmin views now match 2.0 semantics — take the template side on merge.
3. **migra_job** — 1.16, 164 template commits behind. `models.kind` + `Model.from_llm_attributes` override (no 2.0 hook; derive kind from `modalities`/`model.type` in a scope or keep `kind` backfilled by a job after refresh); `AiCost` uses `Tokens.build`/`Cost.new` and cache-token columns → align with template `record_response!` while keeping its extra columns; `embed(dimensions:)` still supported — verify.
4. **sailing_plus** — 1.11, Ruby 4.0.1, dirty tree → ask first. `Chat.ai_record` writes `input_tokens`/`output_tokens`/`cached_tokens`/`model:` onto messages manually → rewrite to `create_or_find_by!` the chat, then `chat.ask(prompt)` (persists message + usage) or record via `chat.ruby_llm_usages`. Keep `purpose`/`subject_*` columns and the 5-column unique index (verify the index survives the SQLite table rebuilds in prepare). Stale `app/tools/models/refresh_models_tool.rb` (`Model.sync_from_ruby_llm!`) → `RubyLLM.models.refresh`.
5. **why_ruby** — 1.14, 94 commits behind with squash-style history (expect heavy conflicts). `Model.resolve` in Post/Testimonial concerns → `RubyLLM::ActiveRecord::Model.enabled.find_by(model_id:) || …` (keep as a small helper on the concern since 96 model_ids exist under several providers — pass `provider:`), stale refresh tool, hardcoded `gpt-4.1-nano` in initializer → `Setting.default_model`.

---

## Self-Review Notes

- Spec coverage: gem to 2.0 (T1, T3); rename-mode generator (T3, T4); app `Model`/`ToolCall` removed in favour of gem classes (T3, T5–T7); cost fully on `ruby_llm_usages` for chats (T4, T6, T7). **Deviation:** translation/embedding/moderation calls are not tied to a chat, and `ruby_llm_usages.chat_id` is NOT NULL, so those keep flowing into `AiCost` — now priced by the gem (`response.cost.total`) instead of the deleted `Model` table.
- Generator hazards covered: string `messages.model_id` (T2), `messages.cost` not carried (T2), usages/batches PK default (T3), assistant messages without a model (T2), copy mode unsupported for string PKs (rename chosen).
