# Template Improvements Spec

> **Audience:** the Rails 8 template at `Code/os/ruby/template`, consumed by dependent projects: `listen_with_me`, `why_ruby`, `sailing_plus`, and the upcoming `migrajob`.
>
> **Nature of this document:** a design spec for primitives that belong in the template (not in any one consuming project) because they are broadly useful. This doc will later become an implementation plan via the `superpowers:writing-plans` skill.
>
> **Principle:** the template stays vanilla Rails / 37signals style. New primitives are added as concerns, polymorphic models, and opt-in patterns. Nothing domain-specific lands here. When a primitive has a solid, battle-tested gem behind it, we prefer the gem — "build it yourself" applies to auth, state, and business logic; it does not apply to wiring Slack webhooks or APNS payloads.

---

## Scope of this revision

Six primitives are in scope. Anything beyond this list is explicitly *out* of the template and belongs in the consuming app.

| Primitive | Why it's in the template |
|---|---|
| **Notifications** (via Noticed v2) | Every app needs to tell a user something. Noticed has adapters for every channel we'll ever want (database, email, Slack, SMS, push, webhook, Teams, Discord…). Building our own was the wrong call — would mean writing and maintaining ten adapters over time. |
| **Conversations** | Already implemented in `sailing_plus`; extracting prevents divergence and future merge conflicts. MigraJob and any other team-scoped app will reuse it. |
| **Searchable** (FTS5) | Universal — any app with a list of things wants full-text search. SQLite's built-in FTS5 is zero-dep. |
| **Embeddable** (sqlite-vec) + RAG kit | Semantic search and similarity matching are useful in most AI-native apps. sqlite-vec is zero-dep, chunk-memory-friendly, runs anywhere SQLite runs. Each consuming app decides per-model whether to enable it. Ships with ordered KNN, metadata pre-filtering, hybrid search via RRF, and chunking. |
| **Dashboards** (Chartkick + Groupdate + KPI scaffolding) | Every app wants an overview screen. Chartkick is tiny, 37signals-blessed, and eliminates the first 80% of dashboard drudgery. |
| **Currencies + Countries** | Almost every team-scoped app handles money and geographic identity. Already well-modularized in `sailing_plus` — extracting prevents re-implementation and inconsistency across dependent projects. |

**Out of scope for the template** (each lives in the consuming app that needs it):
- Statusable / state transition framework (MigraJob-local)
- Reviews / ratings (MigraJob-local)
- Team kinds (agency/employer split) (MigraJob-local)
- Escrow payments (MigraJob-local)
- Verification (MigraJob-local)
- Extractable (LLM-powered file → structured data / OCR) (MigraJob-local)

---

## Current template state (verified)

**Already correct, no change needed:**
- `app/jobs/translate_content_job.rb:32` reads `Setting.translation_model` — it's configurable via Madmin. Documentation referring to `gpt-4.1-nano` as "the model" is misleading; that's just the default fixture value.
- `Setting` model (`app/models/setting.rb`) uses `ALLOWED_KEYS` with a `reconfigure!` hook for RubyLLM / Stripe / SMTP / Litestream; powers the Madmin AI models screen.
- `ProviderCredential` stores API keys and configures RubyLLM via `configure_ruby_llm!`.
- Team / Membership / User tenancy and `/t/:slug` routing are in place.

**Needs cleanup (§7 below):**
- `AGENTS.md:479`, `.claude/rules/multilingual.md:39`, and `article-multilingual.md:47` describe `TranslateContentJob` as if the model were hardcoded. It isn't.
- `README.md` and `AGENTS.md` don't yet list the new primitives from this spec; they need new sections after each primitive lands (§7).

---

## 1. Notifications (Noticed v2)

### Decision

**Use `noticed` gem v2** (excid3). Add it as a template dependency.

Rationale for reversing the earlier "build it ourselves" position:
- Rails ships no notification framework. `ActiveSupport::Notifications` is internal instrumentation — it cannot deliver to a user. Action Notifier is an unmerged RFC ([rails/rails#50454](https://github.com/rails/rails/issues/50454)) with no ship date. `action_push_web` and `action_push_native` are narrow push-delivery adapters, not frameworks.
- Noticed v2 already ships delivery adapters for **database, email, ActionCable, Slack, Vonage (SMS), Twilio (SMS), iOS push, Firebase Cloud Messaging, Microsoft Teams, Discord, Webhook**. Writing all of those ourselves is a months-long project with zero learning value.
- Noticed is maintained by Chris Oliver (GoRails / Jumpstart), has ~10K stars, is battle-tested at production scale, and the v2 architecture (Event + Notification records, pluggable delivery methods) matches exactly what we'd build ourselves.
- Future additions (Slack, SMS, native push) are configuration, not coding.
- 37signals' "build it yourself" principle applies to the *semantic* layer (when to notify, what the notification means, how it affects business logic). Noticed lets us keep full control of that while delegating the protocol chores (APNS payloads, FCM tokens, Twilio signing) to code that's already been debugged by thousands of apps.

### Data model (from Noticed v2)

Noticed v2 creates two tables via its installer:

- `noticed_events` — one row per logical event (e.g. "a deal was confirmed"). Stores `type`, `params`, `record` (polymorphic — the subject the event is about).
- `noticed_notifications` — one row per recipient per event. Stores `recipient` (polymorphic), `read_at`, `seen_at`, `type`.

We run `rails noticed:install:migrations` once in the template and commit the migrations.

### Interface (from Noticed v2)

Consuming apps declare Notifier classes:

```ruby
# app/notifiers/welcome_notifier.rb
class WelcomeNotifier < Noticed::Event
  deliver_by :database
  deliver_by :email, mailer: "NotificationMailer", method: :welcome
  # Later, MigraJob adds more:
  # deliver_by :slack, url: -> { ... }
  # deliver_by :twilio_messaging, ...
end

# Trigger from anywhere:
WelcomeNotifier.with(record: user).deliver(user)
```

Reading:

```ruby
user.notifications.unread
user.notifications.mark_all_as_read
notification.mark_as_read
notification.message  # renders notifier's to_database method
```

### What the template adds on top of Noticed

Noticed is the delivery framework. The template layers:

1. **Install & configure Noticed** — run the installer, commit the migrations, pin a specific version in the Gemfile, add `has_noticed_notifications` to `User` via a `Notifiable` concern.
2. **A reference Notifier** (`WelcomeNotifier`) showing the pattern — database + email delivery, with a mailer template and an in-app partial.
3. **Inbox UI** — `app/controllers/notifications_controller.rb` for list/read/mark-read, `app/views/notifications/index.html.erb` for the inbox layout, `app/views/notifications/_notification.html.erb` for per-row rendering.
4. **Turbo Stream broadcasting** on notification create — so any page with `<%= turbo_stream_from current_user, :notifications %>` gets realtime updates. Opt-in per page.
5. **User preference column** — `User#notification_preferences` JSON column and a `wants_notification?(notifier:, method:)` helper. The helper is called from each delivery method via a conditional:
   ```ruby
   deliver_by :email, if: ->(r) { r.recipient.wants_notification?(notifier: self.class, method: :email) }
   ```
6. **Madmin resource** for `Noticed::Event` and `Noticed::Notification` — so admins can see what got sent and to whom (audit log for free).

### What MigraJob (and any other consuming app) adds

- Its own Notifier classes, one per event type (`DealConfirmedNotifier`, `CandidateExpiringNotifier`, etc.).
- Mailer templates per notifier.
- In-app partials per notifier (`app/views/notifications/kinds/_deal_confirmed.html.erb`).
- Optional: additional delivery methods (Slack, SMS) with their Noticed configuration.

### Files added to template

```
Gemfile                                              # + noticed ~> 2
app/notifiers/application_notifier.rb                # base class
app/notifiers/welcome_notifier.rb                    # reference example
app/models/concerns/notifiable.rb                    # wraps has_noticed_notifications + preference helper
app/mailers/notification_mailer.rb
app/views/notification_mailer/welcome.html.erb
app/views/notifications/index.html.erb
app/views/notifications/_notification.html.erb
app/views/notifications/kinds/_welcome.html.erb
app/controllers/notifications_controller.rb
app/javascript/controllers/notifications_controller.js  # optional: mark-as-read on click
app/madmin/resources/noticed_event_resource.rb
app/madmin/resources/noticed_notification_resource.rb
db/migrate/*_install_noticed.rb                      # from Noticed installer
db/migrate/*_add_notification_preferences_to_users.rb
test/notifiers/welcome_notifier_test.rb
test/controllers/notifications_controller_test.rb
```

### Settings additions

No new `Setting` keys required for Noticed itself. If downstream apps add Slack/SMS deliveries, credentials live in `ProviderCredential` (existing pattern) or encrypted Rails credentials (for secrets that must be present at boot).

---

## 2. Conversations (extracted from sailing_plus)

### Decision

**Extract `sailing_plus`'s existing Conversation / ConversationMessage / ConversationParticipant models to the template**, genericize the domain-specific bits, then add three opt-in enhancements (broadcasting, translation, moderation) that MigraJob needs and `sailing_plus` can adopt later.

Extracting preserves backward compatibility with sailing_plus while preventing further divergence. The alternative — building a second conversation system in the template and leaving sailing_plus on its own — would create merge pain forever.

### Source inventory

Copied with attribution from `sailing_plus`:

| Sailing Plus file | Template destination |
|---|---|
| `app/models/conversation.rb` | `app/models/conversation.rb` |
| `app/models/conversation_message.rb` | `app/models/conversation_message.rb` |
| `app/models/conversation_participant.rb` | `app/models/conversation_participant.rb` |
| `app/controllers/teams/conversations/messages_controller.rb` | `app/controllers/teams/conversations/messages_controller.rb` |
| `app/views/teams/adventures/crew_conversations/show.html.erb` | `app/views/teams/conversations/show.html.erb` (generalized) |
| `app/views/teams/adventures/join_requests/_conversation_message.html.erb` | `app/views/teams/conversations/_conversation_message.html.erb` |
| `app/views/teams/adventures/join_requests/_message_attachments.html.erb` | `app/views/teams/conversations/_message_attachments.html.erb` |
| `app/views/user_mailer/new_conversation_message.html.erb` | `app/views/conversation_mailer/new_message.html.erb` |
| `app/views/user_mailer/new_messages_digest.html.erb` | `app/views/conversation_mailer/messages_digest.html.erb` |
| `app/javascript/controllers/chat_scroll_controller.js` | `app/javascript/controllers/chat_scroll_controller.js` |
| `app/javascript/controllers/chat_input_controller.js` | `app/javascript/controllers/chat_input_controller.js` |
| `app/jobs/conversation_notification_job.rb` | `app/jobs/conversation_notification_job.rb` |
| `app/jobs/conversation_digest_notification_job.rb` | `app/jobs/conversation_digest_notification_job.rb` |
| `test/models/conversation_test.rb` | `test/models/conversation_test.rb` |
| `test/models/conversation_message_test.rb` | `test/models/conversation_message_test.rb` |
| `test/models/conversation_participant_test.rb` | `test/models/conversation_participant_test.rb` |
| `test/controllers/teams/conversations/messages_controller_test.rb` | same |
| `test/controllers/teams/adventures/crew_conversations_controller_test.rb` | `test/controllers/teams/conversations_controller_test.rb` (generalized) |
| `test/jobs/conversation_notification_job_test.rb` | same |
| `test/jobs/conversation_digest_notification_job_test.rb` | same |

### Schema (genericized)

```
conversations
  id             uuid
  team_id        uuid
  subject_type   string   # polymorphic, nullable — was "adventure_id" in sailing_plus
  subject_id     uuid     # nullable
  title          string   # was "subject" in sailing_plus; renamed to avoid collision with polymorphic `subject`
  created_at, updated_at

conversation_participants
  id                uuid
  conversation_id   uuid
  user_id           uuid
  last_read_at      datetime
  last_notified_at  datetime
  created_at, updated_at
  unique index [conversation_id, user_id]

conversation_messages
  id               uuid
  conversation_id  uuid
  user_id          uuid   # sender
  content          text   # nullable — attachments-only messages allowed
  body_translations json  # nullable — populated only if translation is enabled on the consuming model
  flagged_at       datetime # nullable — populated only if moderation is enabled
  flag_reason      string   # nullable
  created_at, updated_at
```

The three nullable columns (`body_translations`, `flagged_at`, `flag_reason`) are part of the template-owned schema from day one. Nullability reflects that translation and moderation are opt-in features — apps that include `TranslatableMessage` and `ModeratableMessage` populate them; apps that don't, leave them null. This is a template design choice, not backwards-compatibility scaffolding.

### One-time sailing_plus update after extraction

Extraction means the template takes ownership of Conversations development from here on — sailing_plus no longer maintains its copy. Immediately after the template extraction lands, sailing_plus gets a one-time update PR:

1. Data migration: `conversations.adventure_id` → `subject_type = 'Adventure'`, `subject_id = adventure.id`, then drop the `adventure_id` column.
2. Column rename: `conversations.subject` → `title`.
3. View relocation: `teams/adventures/join_requests/` → `teams/conversations/`.
4. `User#conversation_email_notifications?` stays in place — it's a user preference, not a conversation concern.

Mechanical, fits in a single commit. After this lands, sailing_plus and template share identical conversation code.

### Enhancement 1: Turbo Stream broadcasting (effectively opt-in)

Added to the template model:

```ruby
class ConversationMessage < ApplicationRecord
  after_create_commit -> { broadcast_append_to conversation }
end
```

This is unconditional in the template but functionally opt-in: if a view doesn't render `<%= turbo_stream_from @conversation %>`, nothing happens. Sailing plus's existing pages don't have that tag, so nothing changes for sailing_plus. MigraJob's pages will have it, so MigraJob gets realtime updates for free.

### Enhancement 2: Translation hook (opt-in via concern)

New concern in template, consuming app opts in:

```ruby
class ConversationMessage < ApplicationRecord
  include TranslatableMessage      # opt-in — translates content into participant locales on create
end
```

`TranslatableMessage`:
- `after_create_commit :enqueue_translation`
- Enqueues `TranslateMessageJob` which looks up the distinct set of `user.preferred_locale` across participants, calls RubyLLM with `Setting.translation_model`, and writes into `body_translations` as `{ "en" => "...", "ru" => "...", "tr" => "..." }`.
- On read, `message.body_for(user)` returns `body_translations[user.preferred_locale] || content`.

Sailing plus doesn't include this concern → no translation happens → nothing changes.

### Enhancement 3: Moderation hook (opt-in via concern)

New concern in template:

```ruby
class ConversationMessage < ApplicationRecord
  include ModeratableMessage       # opt-in — runs regex + optional LLM moderation on create
end
```

`ModeratableMessage`:
- `after_create_commit :enqueue_moderation`
- Enqueues `ModerateMessageJob` which runs:
  1. A default regex covering obvious E.164 phone numbers, emails, @handles, WhatsApp/Telegram URLs.
  2. If `Setting.moderation_model` is set, an LLM pass asking "does this message attempt to share contact information?" Returns JSON `{flagged: bool, reason: string}`.
- On flag, sets `flagged_at`, `flag_reason`. Consumer decides how to render flagged messages (hide, replace with placeholder, alert admin, etc.).
- The regex is overridable by subclass or by including a tighter concern. MigraJob overrides with a stricter list tuned for recruitment.

### Integration with Noticed

Digest and new-message emails can optionally route through Noticed Notifiers instead of the plain ActionMailer extracted from sailing_plus. The template ships the sailing_plus code as-is (plain `ActionMailer`) to minimize the sailing_plus migration, and MigraJob wraps new-message notifications in a `NewMessageNotifier` locally. This keeps the Conversations primitive independent of Noticed at the record layer — consuming apps decide whether to route messages through Noticed.

### Setting additions for conversations

- `Setting::ALLOWED_KEYS` gains `:moderation_model` (nullable — if nil, only regex moderation runs).
- Madmin AI models screen gains a "Moderation model" field.

### Files added to template

```
app/models/conversation.rb
app/models/conversation_message.rb
app/models/conversation_participant.rb
app/models/concerns/translatable_message.rb         # opt-in
app/models/concerns/moderatable_message.rb          # opt-in
app/controllers/teams/conversations_controller.rb
app/controllers/teams/conversations/messages_controller.rb
app/views/teams/conversations/...                    # generalized views
app/mailers/conversation_mailer.rb
app/views/conversation_mailer/...
app/jobs/conversation_notification_job.rb
app/jobs/conversation_digest_notification_job.rb
app/jobs/translate_message_job.rb
app/jobs/moderate_message_job.rb
app/javascript/controllers/chat_scroll_controller.js
app/javascript/controllers/chat_input_controller.js
db/migrate/*_create_conversations.rb                 # genericized from sailing_plus
db/migrate/*_create_conversation_participants.rb
db/migrate/*_create_conversation_messages.rb
db/migrate/*_add_moderation_model_to_settings.rb
test/models/conversation*_test.rb                    # copied + adapted
test/controllers/teams/conversations_controller_test.rb
test/jobs/conversation_*_test.rb
```

---

## 3. Searchable (SQLite FTS5)

### Decision

SQLite's built-in FTS5 via a virtual table per searchable model. No `pg_search`, no Meilisearch, no external services.

### Pattern

```ruby
class Thing < ApplicationRecord
  include Searchable
  searchable_fields :name, :description, :tags
end

Thing.search("welder russian speaker")
# → joins <model>_fts virtual table, returns Thing records in relevance order
```

### Implementation

- A migration generator creates the `<model>_fts` virtual table with `tokenize = 'porter unicode61 remove_diacritics 2'` — handles Cyrillic and Turkish diacritics correctly out of the box.
- `after_save_commit` updates the FTS row.
- `after_destroy_commit` removes it.
- Rake task `fts:rebuild[model]` for full reindex.
- `.search(query)` returns an ActiveRecord::Relation so it composes with scopes.

### Files

```
app/models/concerns/searchable.rb
lib/tasks/searchable.rake
lib/generators/searchable/install/install_generator.rb
lib/generators/searchable/install/templates/migration.rb.tt
test/models/concerns/searchable_test.rb
```

### Setting additions

- `Setting::ALLOWED_KEYS` gains `:search_tokenizer` (default `"porter unicode61 remove_diacritics 2"`) so apps can override without a deploy.

---

## 4. Embeddable (sqlite-vec) + RAG primitives

### Decision

`sqlite-vec` extension (Alex Garcia), loaded at boot via `config/initializers/sqlite_vec.rb`. Chunked shadow tables keep memory bounded — matters on Kamal boxes. Mirrors the FTS5 mental model from §3: you declare a virtual table per model, query it, join back to get records.

The template ships not just basic `similar_to` but the standard **RAG retrieval kit**: ordered results, configurable distance metrics, metadata pre-filtering, hybrid search that fuses FTS5 + vector scores via Reciprocal Rank Fusion, and a chunking pattern for long documents. This is what consuming apps actually need — bare similarity search is rarely enough on its own.

**Why in the template:** semantic search, similarity matching, dedup, and small-scale RAG come up in most AI-native apps. Having the primitive and its retrieval kit ready means each consuming app decides *per model* whether to opt in, not whether to bring the whole retrieval stack online.

### Why sqlite-vec specifically

- Chunked shadow tables — vectors read chunk-by-chunk during KNN, no full load into RAM.
- Mirrors FTS5: declare a virtual table, insert/update/delete normally, query with SELECT.
- Zero external dependencies — no BLAS, no Faiss. Runs in WASM, mobile, Kamal containers.
- Native support for cosine, L2, L1, and Hamming distance metrics.
- Metadata columns on vec0 tables are indexed and filtered *before* KNN distance calculation — "WHERE-aware KNN" that saves compute at scale.
- Alex Garcia's own writing documents the hybrid FTS5+vector pattern with RRF — the template implements that pattern as a first-class helper.

### Basic pattern — ordered similarity search

```ruby
class Thing < ApplicationRecord
  include Embeddable

  embeddable_source ->(record) { "#{record.name} #{record.description}" }
  embeddable_model  -> { Setting.embedding_model }
  embeddable_distance :cosine   # :cosine (default for text), :l2, :l1, :hamming
end

Thing.similar_to("welder with marine experience", limit: 20)
# → embeds the query with Setting.embedding_model
# → KNN against things_embeddings vec0 table ORDER BY distance ASC (nearest first)
# → returns ActiveRecord::Relation of Thing records in similarity order
# → distance is preserved on each record via a virtual attribute: record.similarity_distance
```

**Order guarantee**: `similar_to` always returns records ordered by distance ascending (most similar first). This is not optional — it's the natural ordering of a KNN query in sqlite-vec and the concern exposes it as the only ordering. Consuming code can read `record.similarity_distance` to show match confidence in the UI.

### Metadata pre-filtering

vec0 tables support metadata columns that are filtered *before* KNN runs — a WHERE-aware KNN. The concern exposes this as `filter_by:` on `similar_to`:

```ruby
# Declare metadata columns on the vec0 table in the generator
create_virtual_table :candidate_embeddings, :vec0, [
  "id integer primary key",
  "embedding float[1536] distance_metric=cosine",
  "nationality text",         # metadata column
  "profession text",          # metadata column
  "years_experience integer"  # metadata column
]
```

```ruby
# Use them at query time
Candidate.similar_to(
  "welder with marine experience",
  limit: 20,
  filter_by: { nationality: "UZ", years_experience: 3.. }
)
# → WHERE nationality = 'UZ' AND years_experience >= 3
# → then KNN on the filtered subset
# → much faster than post-filtering
```

Metadata columns are populated automatically by the concern via a `embeddable_metadata` declaration:

```ruby
embeddable_metadata ->(record) {
  {
    nationality: record.nationality_code,
    profession: record.profession,
    years_experience: record.experience_years
  }
}
```

Metadata columns are updated on every embedding refresh — they're part of the same row.

### Hybrid search (FTS5 + vector via Reciprocal Rank Fusion)

Pure vector search is weak on exact keyword matches ("welder" with no synonym context) and FTS5 is weak on semantic matches ("marine engineering" ≈ "boat mechanic"). The industry-standard fix is **Reciprocal Rank Fusion**: run both searches, combine their ranks.

The template adds a `HybridSearchable` concern that pulls in both `Searchable` and `Embeddable` and exposes one method:

```ruby
class Candidate < ApplicationRecord
  include Searchable
  include Embeddable
  include HybridSearchable     # opt-in — requires the other two

  searchable_fields :profession, :skills, :notes
  embeddable_source ->(r) { "#{r.profession} #{r.skills} #{r.experience_summary}" }
end

Candidate.hybrid_search("welder marine experience", limit: 20)
# → runs FTS5 (ordered by bm25 relevance)
# → runs vector similarity (ordered by distance)
# → fuses via RRF: score = Σ (1 / (k + rank_in_list)) where k=60 (standard)
# → returns ActiveRecord::Relation ordered by fused score
```

RRF implementation reference: [Alex Garcia's hybrid search post](https://alexgarcia.xyz/blog/2024/sqlite-vec-hybrid-search/index.html). The template implements it as a single SQL query with two CTEs (one FTS5, one vec0) joined on the record ID.

**`k=60`** is the standard RRF constant from Cormack et al.'s original paper. Exposed as `Setting.rrf_k` in case a consuming app wants to tune it.

### Chunking for long documents

For content longer than ~500 tokens (articles, documents, long descriptions), single-vector embeddings lose fidelity. The template provides a `Chunkable` concern that pairs with `Embeddable`:

```ruby
class Article < ApplicationRecord
  include Embeddable
  include Chunkable

  embeddable_source ->(chunk) { chunk.content }      # note: chunk, not record
  chunk_source      ->(record) { record.body }      # the text to split
  chunk_size 400                                     # tokens per chunk, default 400
  chunk_overlap 40                                   # overlap in tokens, default 10%
end

Article.similar_to("onboarding process", limit: 10)
# → returns Article records (deduped), ordered by the best-matching chunk's distance
# → each record has .best_chunk loaded for snippet rendering
```

The template ships a simple sentence-boundary tokenizer for chunking (no extra gem). A `Chunk` model holds `chunkable_type`, `chunkable_id`, `position`, `content` — polymorphic so any `Chunkable` model can use it. Chunks have their own vec0 table. Query deduplicates to the parent record but surfaces the best-matching chunk for snippet display.

Chunking is opt-in. Candidates (short text) don't need it; Articles (long text) do.

### Caching: skip re-embedding unchanged content

Every call to the embedding API costs money and adds latency. The template's `Embeddable` hashes the source string and stores the hash in the vec0 metadata. Before re-embedding on save, it checks: if the hash matches the stored one, skip the API call. If the source changed, re-embed. This is a single `if previous_source_hash == current_source_hash; return; end` check in `EmbedRecordJob`.

### Implementation

- `config/initializers/sqlite_vec.rb` loads the sqlite-vec extension on every connection (`SQLite3::Database#enable_load_extension`, then `load_extension(path)`).
- `Embeddable` concern provides:
  - `embeddable_source`, `embeddable_model`, `embeddable_distance`, `embeddable_metadata` DSL.
  - `after_save_commit :enqueue_embedding` — if the source string changed (hash check).
  - `after_destroy_commit :purge_embedding`.
  - `similar_to(query, limit:, filter_by:)` — class method that embeds the query and runs KNN. Returns an AR::Relation in distance order.
- `Chunkable` concern provides chunking via a simple sentence-boundary splitter, the polymorphic `Chunk` model, and the chunked vec0 table.
- `HybridSearchable` concern requires both `Searchable` and `Embeddable` and exposes `hybrid_search`.
- `EmbedRecordJob` — calls RubyLLM with the configured embedding model, upserts into `<model>_embeddings` vec0 table keyed by record ID, plus metadata columns.
- Migration generator creates the vec0 virtual table per model with configurable distance metric and metadata columns.
- Rake task `embeddings:rebuild[model]` for full reindex after model or source changes.

### Files

```
Gemfile                                                # no gem — sqlite-vec is a loadable extension
vendor/sqlite-vec/                                     # binaries for linux-x86_64, linux-aarch64, darwin-arm64
config/initializers/sqlite_vec.rb
app/models/concerns/embeddable.rb
app/models/concerns/chunkable.rb
app/models/concerns/hybrid_searchable.rb
app/models/chunk.rb                                    # polymorphic chunk model
app/jobs/embed_record_job.rb
lib/tasks/embeddable.rake
lib/generators/embeddable/install/install_generator.rb
lib/generators/embeddable/install/templates/migration.rb.tt
test/models/concerns/embeddable_test.rb
test/models/concerns/chunkable_test.rb
test/models/concerns/hybrid_searchable_test.rb
```

### Setting additions

- `:embedding_model` (default `"text-embedding-3-small"`)
- `:rrf_k` (default `60` — Cormack et al. standard for Reciprocal Rank Fusion)

Madmin AI models screen gains an "Embedding model" field and a "Hybrid search RRF constant" field.

### Installation note

sqlite-vec ships a loadable extension, not a Ruby gem. The initializer resolves the extension path (vendored `.dylib` / `.so` / `.dll` in `vendor/sqlite-vec/`) based on the current platform. Template ships the binaries for `linux-x86_64`, `linux-aarch64`, and `darwin-arm64` in the repo. Kamal deploy copies `vendor/sqlite-vec/` into the container via a Dockerfile `COPY` instruction (template's Dockerfile is updated as part of this primitive's PR).

### What's explicitly out of scope

- **Vector database alternatives** (Pinecone, Weaviate, Qdrant, pgvector). SQLite's vec0 handles the scale of any app we'd build on this template. If an app outgrows it, it's a one-off swap at that time, not a template concern.
- **Re-ranking models** (Cohere Rerank, etc.) — out of scope for v1. RRF is good enough for our scale. Can be added as a `HybridSearchable.rerank(results, with: :cohere)` hook later if needed.
- **Query expansion** (HyDE, multi-query) — same reasoning. Simple RRF gets 80% of the quality at 5% of the complexity.

---

## 5. Dashboards

### Decision

Extract the dashboard machinery from `sailing_plus` (`/Users/yurisidorov/Code/my/ruby/sailing_plus`), genericize the sailing-domain pieces, and add what sailing_plus is missing (reusable KPI card partial, cache pattern, time-range selector). Add `chartkick` + `groupdate` as the gems, with `Chart.bundle` for when we need direct Chart.js access.

Sailing_plus already has: controller-level data aggregation, `column_chart` usage, SVG progress rings, SVG sparklines, currency formatting helpers, and a reference admin dashboard with KPI cards + subscription stats + top lists. That's most of what any consuming app needs — we just lift it and de-domain it.

### What gets extracted from sailing_plus

| Sailing Plus source | Template destination | Notes |
|---|---|---|
| `Gemfile: chartkick` | `Gemfile` | Add + `groupdate` for time bucketing |
| `config/importmap.rb: chartkick, Chart.bundle` pins | same | Lift pins verbatim |
| `app/helpers/application_helper.rb#format_amount`, `currency_symbol`, `currency_name` | `app/helpers/application_helper.rb` | Already template-useful beyond dashboards |
| `app/helpers/adventures_helper.rb#progress_ring` (with sailing-specific defaults) | `app/helpers/dashboard_helper.rb#progress_ring` | Rename, drop cover-image and sailing-specific color tables; keep SVG math |
| `app/helpers/adventures_helper.rb#views_sparkline` | `app/helpers/dashboard_helper.rb#sparkline` | Rename, keep the SVG area+line pattern and pixel mapping |
| `app/javascript/controllers/sparkline_controller.js` | same | Tooltip-on-hover interaction; domain-agnostic |
| `app/javascript/controllers/revenue_chart_controller.js` | `app/javascript/controllers/chart_theme_controller.js` | Post-render Chart.js theming in oklch; generalize to any chart |
| `app/controllers/madmin/dashboard_controller.rb` | same | Lift verbatim — it's already generic (users, teams, chats, messages, AI cost). Sailing_plus admin dashboard is a template-quality reference |
| `app/views/madmin/dashboard/show.html.erb` | same | Same reasoning |
| `test/controllers/home_controller_test.rb` (dashboard-related tests) | `test/controllers/home_controller_test.rb` | Adapt to the generic reference dashboard |

### What the template adds that sailing_plus doesn't have

Sailing_plus has a lean, inline-heavy dashboard style with no component library and no caching. Template ships the missing patterns:

1. **Reusable `_kpi_card.html.erb` partial** — sailing_plus inlines every KPI. Template extracts the pattern so consuming apps can write `<%= render "shared/kpi_card", label: t(".active_users"), value: @active_users, trend: @trend %>`.
2. **`_chart_card.html.erb` partial** — wraps a Chartkick chart with a title, subtitle, and optional time-range selector dropdown.
3. **`_attention_items_strip.html.erb` partial** — genericized from sailing_plus's color-coded action badges. Takes `items:` (array of `{severity:, label:, path:}`) and renders. Severities map to Tailwind OKLCH theme colors.
4. **Time-range selector** — sailing_plus has no period picker. Template ships `app/javascript/controllers/time_range_controller.js` that posts `?range=7d|30d|90d|custom` back to the controller, plus a helper `time_range_options_for(param)` that sets `@range` from params and provides `@range_start`, `@range_end`, and helper methods for chart queries:
   ```ruby
   # In a dashboard controller
   @range = time_range_from(params[:range] || "30d")
   @chart_data = Candidate.where(created_at: @range).group_by_day(:created_at).count
   ```
5. **Cache wrapping for expensive aggregations** — sailing_plus has one cache wrap (the Stripe MRR call, 15-minute TTL). Template generalizes to a helper:
   ```ruby
   # In DashboardHelper
   def cached_dashboard(key, expires_in: 5.minutes, &block)
     Rails.cache.fetch(["dashboard", current_team&.id, key, @range].compact, expires_in: expires_in, &block)
   end
   ```
   Consuming apps wrap their aggregations: `@top_things = cached_dashboard(:top_things) { Thing.ranked_by_value.limit(10).to_a }`. Cache invalidates automatically on time-range change via the `@range` in the cache key.
6. **Reference team dashboard** at `app/views/home/dashboard.html.erb` showing:
   - KPI card row (4 cards) using the new partial.
   - Attention items strip.
   - Time-range selector.
   - Line chart of activity over the selected range.
   - Breakdown column chart.
   - Empty state.
7. **Reference admin dashboard** at `app/views/madmin/dashboard/show.html.erb` (lifted from sailing_plus) showing:
   - 6 KPI cards in a gradient grid (Users / Teams / Chats / Messages / AI Tokens / AI Cost).
   - 7-day cost timeline.
   - Subscription stats card (Stripe MRR, counts by status).
   - Top teams by AI cost.
   - Top users by AI cost.
   - Recent chats activity feed.
   - Caching on MRR and top-lists.

### Helper surface

```ruby
module DashboardHelper
  def kpi_card(label:, value:, trend: nil, icon: nil, href: nil); end
  def progress_ring(value:, max:, size: 48, label: nil); end
  def sparkline(series, width: 120, height: 32); end
  def attention_items_strip(items); end
  def pct_change(current, previous); end
  def trend_arrow(delta); end
  def cached_dashboard(key, expires_in: 5.minutes, &block); end
  def time_range_from(param); end # returns Range
end
```

### Performance defaults the template enforces

Sailing_plus's dashboard loads ~a dozen adventures with deep `includes`. That's a good pattern, but the template codifies it as a rule in documentation (and in `.claude/rules/performance.md`):

- Every dashboard query must use `includes` for any association accessed in the view.
- Every "top N" query must use a database aggregate, not Ruby iteration on preloaded data.
- Every expensive aggregation (anything that hits an external API or joins 3+ tables with group-by) must be wrapped in `cached_dashboard`.
- Every dashboard controller action must have a test that asserts the query count is ≤ N (where N is documented in the test).

### Files

```
Gemfile                                                 # + chartkick, + groupdate
config/importmap.rb                                     # pin chartkick + Chart.bundle
app/helpers/application_helper.rb                       # + format_amount, currency_symbol, currency_name
app/helpers/dashboard_helper.rb                         # kpi_card, progress_ring, sparkline, attention_items_strip, cached_dashboard, time_range_from, pct_change, trend_arrow
app/views/shared/_kpi_card.html.erb
app/views/shared/_chart_card.html.erb
app/views/shared/_attention_items_strip.html.erb
app/views/shared/_progress_ring.html.erb
app/views/home/dashboard.html.erb                       # reference team dashboard
app/views/madmin/dashboard/show.html.erb                # reference admin dashboard (lifted from sailing_plus)
app/controllers/madmin/dashboard_controller.rb          # lifted from sailing_plus
app/javascript/controllers/sparkline_controller.js
app/javascript/controllers/chart_theme_controller.js    # was revenue_chart_controller.js in sailing_plus
app/javascript/controllers/time_range_controller.js     # new in template
test/helpers/dashboard_helper_test.rb
test/controllers/home_controller_test.rb
test/controllers/madmin/dashboard_controller_test.rb    # sailing_plus has no admin dashboard tests; template adds them
```

### What's not in the template

Chart pickers, dashboard CRUD, "customize your dashboard" UI, or any domain-specific widget. Each app writes its own dashboard; the template just removes the plumbing drudgery and ships a working reference of both a team dashboard and an admin dashboard.

---

## 6. Currencies + Countries

### Decision

Extract `sailing_plus`'s currency infrastructure (`/Users/yurisidorov/Code/my/ruby/sailing_plus`) almost verbatim — it's well-modularized via the `CurrencyConvertible` concern and has zero sailing-specific coupling. Upgrade the country handling to match (sailing_plus's country story is minimal and inconsistent; template ships a complete version).

This is a pure "stop reinventing" move. Any team-scoped app (MigraJob, why_ruby, listen_with_me, future projects) will need currency display, conversion, and country pickers. Shipping this once in the template prevents three-to-five divergent half-implementations.

### What gets extracted from sailing_plus

| Sailing Plus source | Template destination | Notes |
|---|---|---|
| `app/models/concerns/currency_convertible.rb` | `app/models/concerns/currency_convertible.rb` | Lift verbatim: `POPULAR_CURRENCIES`, `SUPPORTED_CURRENCIES`, `CURRENCY_NAMES`, `convert_amount` helper |
| `Gemfile: money + money-open-exchange-rates OR money-currencylayer-bank` | `Gemfile` | Keep the Money gem + `Money::Bank::CurrencylayerBank` pattern |
| CurrencyLayer API integration (24h cache in `tmp/cache/money`) | same | Bank configured in an initializer, API key via `Setting.get(:currencylayer_api_key)` (already in existing `ALLOWED_KEYS`) |
| `app/helpers/application_helper.rb` currency helpers | same file in template | `currency_symbol`, `currency_name`, `currency_options_for_select`, `format_amount` |
| `app/views/shared/_currency_amount.html.erb` | same | Grouped select (popular / rest) + amount input, dark-themed, Stimulus target attrs |
| `app/javascript/helpers/currency.js` | same | `currencySymbol(code)` ES module |
| `app/javascript/controllers/currency_select_controller.js` | same | Symbol on selection, full name on blur |
| `config/locales/en/currencies.yml` | same | 72 currency name translations |
| Migrations: `add_default_currency_to_teams`, `add_preferred_currency_to_users` | `add_currency_fields` (single consolidated migration) | Template adds `teams.default_currency` (default `"USD"` to be domain-neutral, override in consuming app) and `users.preferred_currency` nullable |
| `ApplicationController#detect_currency` + fallback chain | same | Fallback chain: `user.preferred_currency → cookie → IP-country → team default → USD` |
| `Current.currency` attribute + `set_currency` before_action | same | Request-local currency context |
| `COUNTRY_CURRENCY` hash (IP-country → currency mapping) | `app/models/concerns/currency_convertible.rb` constant | Already domain-agnostic in sailing_plus |

### What the template adds that sailing_plus is missing

Sailing_plus's country handling is minimal — it just does ISO 3166 lookups where needed. For template-level use, we need a proper Country primitive so every consuming app has the same mental model.

1. **`countries` gem** (`iso3166` / `countries`) — already used transitively in sailing_plus; template pins it explicitly.
2. **`Countryable` concern** — applied to models that have a country code column:
   ```ruby
   class Team < ApplicationRecord
     include Countryable
     countryable :country_code   # → validates against ISO 3166 alpha-2, adds country helper method
   end

   team.country           # → ISO3166::Country instance
   team.country_name      # → localized via current locale
   team.country.flag      # → emoji flag
   ```
3. **`country_options_for_select(selected, include_blank: false)`** helper — sorted alphabetically in current locale, returns `[["🇺🇸 United States", "US"], ...]` pairs with emoji flags prefixed. Uses `ISO3166::Country.translations[I18n.locale.to_s]`.
4. **`country_name(alpha2)` helper** — same as sailing_plus.
5. **`country_flag(alpha2)` helper** — returns emoji flag string (e.g. `"🇺🇸"`).
6. **Shared partial** `app/views/shared/_country_select.html.erb` — Tailwind-styled grouped select with search (Stimulus controller does client-side filter) + flag emoji prefix. Optionally restricts to an allow-list passed as `countries: ["US", "GB", "DE"]` for when a consuming app wants only EU countries, for example.
7. **Stimulus controller** `country_select_controller.js` — debounced client-side filter on the select options, preserves keyboard navigation.
8. **`users.residence_country_code`** added as a migration (nullable). Sailing_plus has `nationality` as a free-text string; template ships the canonical version.
9. **`teams.country_code`** added as a migration. Sailing_plus has nothing at team level; template ships this because it's commonly useful (invoice addresses, compliance, payment routing).
10. **Settings screen entries** for "Default currency" and "Country" under `/t/:slug/settings` — added to existing `Teams::SettingsController` view.
11. **Preferences screen entries** for "Preferred currency" and "Country" under user preferences — added to existing user profile view.
12. **Locale-aware currency formatting** — sailing_plus's `format_amount` uses Rails' `number_with_delimiter` with hardcoded delimiter. Template uses the current locale's delimiter via `I18n.t("number.format.delimiter")` so Russian renders `1 000 000,00` and English renders `1,000,000.00`.

### Cross-primitive integration

- **With Conversations**: `User#preferred_locale` is already handled; template's `TranslatableMessage` uses it. Currency doesn't affect conversations.
- **With Dashboards**: the dashboard `kpi_card` helper already calls `format_amount`. After this primitive lands, it automatically picks up the Money-backed conversion. KPI cards that show monetary values read `Current.currency` for display.
- **With Noticed notifications**: payment-related notification mailers use `format_amount(value, in: Current.currency)` so the email is rendered in the recipient's preferred currency.

### Rates refresh strategy

CurrencyLayer's free tier is 100 requests/month. Sailing_plus relies on the built-in 24h cache in `money-currencylayer-bank` + the `tmp/cache/money` file cache. Template:

1. Keeps the 24h in-memory cache (Money gem default).
2. Adds a daily Solid Queue recurring job `RefreshCurrencyRatesJob` that warms the cache once per day at 04:00 UTC. The job simply calls `Money.default_bank.update_rates` and logs the result. This ensures rates are fresh without blocking a user request on an API call.
3. Caches the `Money::Currency.table` in Solid Cache so currency metadata is read from the DB, not recomputed per request.

### Files added to template

```
Gemfile                                                    # + money, + money-currencylayer-bank, + countries (iso3166)
config/initializers/money.rb                               # Bank setup, default currency, cache dir
config/locales/en/currencies.yml                           # 72 currency names (from sailing_plus)
config/locales/ru/currencies.yml                           # Russian translations (new — not in sailing_plus)
app/models/concerns/currency_convertible.rb                # Lifted from sailing_plus
app/models/concerns/countryable.rb                         # New in template
app/helpers/application_helper.rb                          # + currency_symbol, currency_name, format_amount, currency_options_for_select, country_name, country_flag, country_options_for_select
app/views/shared/_currency_amount.html.erb                 # Lifted from sailing_plus
app/views/shared/_country_select.html.erb                  # New in template
app/javascript/helpers/currency.js                         # Lifted from sailing_plus
app/javascript/controllers/currency_select_controller.js   # Lifted from sailing_plus
app/javascript/controllers/country_select_controller.js    # New in template
app/jobs/refresh_currency_rates_job.rb                     # New in template
app/controllers/application_controller.rb                  # + detect_currency, set_currency, Current.currency
app/models/current.rb                                      # + attribute :currency
db/migrate/*_add_currency_fields_to_teams_and_users.rb     # Consolidated from sailing_plus migrations
db/migrate/*_add_country_code_to_teams_and_users.rb        # New in template
test/models/concerns/currency_convertible_test.rb
test/models/concerns/countryable_test.rb
test/helpers/application_helper_test.rb                    # Currency + country helper tests
test/jobs/refresh_currency_rates_job_test.rb
```

### Settings additions

`Setting::ALLOWED_KEYS` gains (or confirms):
- `:currencylayer_api_key` — already in sailing_plus, adopt
- `:default_currency` — platform default, falls back to `"USD"`
- `:default_country_code` — platform default, falls back to `nil`

Madmin Settings screen gains a "Currencies & Countries" section with these three fields.

### Resolution order for "current currency"

Matches sailing_plus's established chain (and documents it as the template convention):

1. `Current.user.preferred_currency` — if logged in and set
2. `cookies[:tmpl_currency]` — renamed from sailing_plus's `sailing_currency` cookie
3. IP → country → `COUNTRY_CURRENCY[code]` (via existing IP geolocation if configured)
4. `Current.team.default_currency` — if in a team context
5. `Setting.get(:default_currency)` — platform default
6. `"USD"` — hard fallback

Documented explicitly in `AGENTS.md` under a new "Currency resolution" subsection so contributors don't reinvent the chain.

### What's explicitly out of scope

- **Per-record amount conversion caching** — sailing_plus converts on the fly in `Adventure#formatted_price_in`. At template scale, this is fine. If an app later needs precomputed conversions (e.g. for dashboards showing aggregate revenue), it adds its own materialized-view pattern.
- **Multi-currency wallets / balance tracking** — way beyond template scope. Lives in whatever app needs it.
- **Historical exchange rates** — only current rates are stored. Apps that need historical (audit trails, invoice lock-in) handle it in their own models.
- **Regional subdivisions** (states/provinces/oblasts) — just country-level for now. ISO 3166-2 support can be added later as `Subdivisionable` if a consuming app needs it.
- **Timezone-per-country** — handled via Rails' built-in `ActiveSupport::TimeZone`, not here. Country selection does not auto-set timezone.

---

## 7. Documentation updates

Template `README.md` and `AGENTS.md` must be updated as each primitive lands so that downstream projects (and AI agents consuming the repo) have accurate, current guidance. This is a hard requirement — out-of-date docs in a template propagate misleading information to every consuming project.

### Non-code housekeeping (applies first, before any primitive lands)

- **`AGENTS.md:479`** — change  
  *"TranslateContentJob → LLM translation via gpt-4.1-nano"*  
  to  
  *"TranslateContentJob → LLM translation via the model configured in Madmin at `Setting.translation_model`"*.
- **`.claude/rules/multilingual.md:39`** — change  
  *"Job calls `RubyLLM.chat(model: \"gpt-4.1-nano\")` with JSON prompt"*  
  to  
  *"Job calls `RubyLLM.chat(model: Setting.translation_model)` with JSON prompt"*.
- **`article-multilingual.md:47`** — historical article; leave prose intact but add a footnote: *"Since writing this, the model is configured in Madmin; `gpt-4.1-nano` is just the current default."*
- **Add a new top-level section to `AGENTS.md`**: **"Nothing hardcoded: all LLM models are Madmin-configurable via Setting"** — states the rule explicitly so contributors and AI agents don't introduce regressions.

### Per-primitive documentation (each primitive's work is not "done" until this lands)

Each primitive in §§1–6 above adds sections to both `README.md` and `AGENTS.md`. Required updates:

| Primitive | `README.md` section | `AGENTS.md` section |
|---|---|---|
| Notifications (§1) | New "Notifications" under **Features**, with a line item in **Tech Stack** referencing `noticed ~> 2` | New "Notifications" top-level section showing how to declare a Notifier, deliver an event, and read the inbox |
| Conversations (§2) | New "Messaging" under **Features** with a note that team-to-team chat is team-scoped | New "Conversations" top-level section covering the model, opt-in concerns (`TranslatableMessage`, `ModeratableMessage`), and Turbo broadcasting behavior |
| Searchable (§3) | Add bullet under **Features** → "Full-text search via SQLite FTS5" | New "Searchable" section showing `include Searchable`, the tokenizer default, and the `search(query)` usage |
| Embeddable (§4) | Add bullet under **Features** → "Vector search via sqlite-vec" and update **Tech Stack** with "Vector search: sqlite-vec" | New "Embeddable" section showing `include Embeddable`, the embedding model setting, `similar_to` / `hybrid_search` / `Chunkable` usage, and the Kamal/Dockerfile step for shipping the extension binary |
| Dashboards (§5) | Add bullet under **Features** → "Dashboard scaffolding (Chartkick + Groupdate)" and update **Tech Stack** | New "Dashboards" section showing `kpi_card` helper and a reference to the example dashboard view |
| Currencies + Countries (§6) | Add bullet under **Features** → "Currency conversion + country pickers" and update **Tech Stack** with "Money gem, iso3166" | New "Currencies + Countries" top-level section showing `include Countryable`, `CurrencyConvertible`, the resolution chain for `Current.currency`, and the CurrencyLayer setup step |

Every primitive's implementation PR must include its doc updates in the same commit as the code. Reviewer rejects the PR if either the code or the docs are missing.

### `CLAUDE.md` update

`CLAUDE.md` includes `AGENTS.md` via `@AGENTS.md` so it auto-updates. No separate edit needed unless we introduce a new *rule* (e.g. "always use Noticed for notifications, don't build your own"). That rule should be added to `.claude/rules/` as a new file if it materializes — likely `.claude/rules/notifications.md` after §1 lands.

---

## 8. Locale readiness

MigraJob will eventually need `tg`, `uz`, `ky`, `tr`, `sr`; other dependent projects currently ship `en, de, es, fr, ru`. Changes:

- Nothing in code — the `Language` model already syncs from `config/locales/*.yml` files at boot.
- Add language-name stubs to `config/locales/en.yml` (and `ru.yml`) so the Madmin language picker shows the new languages with human-readable names when a consuming app adds the full locale files.

Actual locale content for each new language is the consuming app's job.

---

## Dependencies summary

New dependencies added to the template:

| Dependency | Type | Purpose | Why it's here |
|---|---|---|---|
| `noticed ~> 2` | Gem | Notification framework | Battle-tested, ten delivery adapters, maintained by Chris Oliver. Reverses an earlier "build it ourselves" decision. |
| `chartkick` | Gem | Dashboard charts | Tiny, ESM-pinned, 37signals-blessed |
| `groupdate` | Gem | Time-bucket queries | Pairs with chartkick |
| `sqlite-vec` | SQLite loadable extension (not a Ruby gem) | Vector search | Zero-dep, chunk-memory-friendly, same mental model as FTS5 |
| `money` | Gem | Currency modelling + formatting | Industry standard, already used in sailing_plus |
| `money-currencylayer-bank` | Gem | Rates provider integration | Pairs with Money gem; free tier is sufficient for template-scale apps |
| `countries` (iso3166) | Gem | ISO 3166 country data + localized names + flag emoji | Replaces sailing_plus's minimal ad-hoc country lookups |

No gems removed. No new gems for conversations (code is moving from sailing_plus). No new gems for FTS5 search (built into SQLite).

**Deferred** (added by consuming apps that need them, not the template):
- `noticed` delivery method packages for Slack, Twilio, Vonage, iOS push, FCM — all first-class in Noticed v2 but bring their own dependencies (httparty, twilio-ruby, etc.). Template opts in per-consumer, not template-wide.

---

## Explicitly out of scope

Each of the following was considered and rejected for the template. They live in the consuming app that needs them. See `migrajob.md` §13.2 for how MigraJob implements the ones it needs:

- Statusable / state transition framework — too domain-specific; different consumers want different shapes.
- Reviews / ratings — same.
- Team kinds (agency/employer split) — MigraJob specific.
- EscrowPayment + Stripe manual-capture wiring — only useful in marketplace apps.
- Verifiable / Verification queue — KYC-flavored, too domain-specific.
- Extractable / parsekit / LLM OCR pipeline — specific to apps that ingest documents; each has different schemas and prompts.
- Action Notifier migration (unknown timeline; Noticed is our current answer).

If one of these later proves useful in *two or more* template-consuming apps, it becomes a candidate for promotion into the template. Until then, premature generalization is the enemy.

---

## Order of work (to become a plan)

1. **Documentation housekeeping (§7, non-code part)** — 15 minutes, zero risk, stops misleading guidance before any downstream reader trusts it.
2. **Notifications via Noticed (§1)** — foundational; conversations digest optionally wraps it later.
3. **Conversations extraction (§2)** — move sailing_plus code first, then add the three opt-in concerns. Includes the sailing_plus follow-up migration PR.
4. **Currencies + Countries (§6)** — lifts more sailing_plus code (`CurrencyConvertible`, helpers, partials, JS controllers), adds the new `Countryable` concern. Lands before Dashboards because the dashboard `kpi_card` helper reads `Current.currency`.
5. **Searchable (§3)** — independent, low risk.
6. **Embeddable (§4)** — depends only on the new Setting key and the sqlite-vec extension binary; otherwise isolated.
7. **Dashboards (§5)** — depends on §6 for currency-aware KPI cards and on `chart_theme_controller.js` extraction from sailing_plus.
8. **Per-primitive documentation (§7, per-primitive part)** — lands *with* each primitive's code, not after.
9. **Locale readiness (§8)** — trivial, can land any time.

Each step is independently mergeable and each leaves the template in a working state.

---

## Cross-project coordination

Because the template is consumed by multiple projects, these changes need coordination:

| Project | Impact |
|---|---|
| `listen_with_me` | No impact — none of these primitives conflict with existing code. Picks up the new primitives on next template merge. Can optionally start using Noticed, Embeddable, or dashboards. |
| `why_ruby` | Same as above. |
| `sailing_plus` | **Breaking**: conversations extraction requires a one-time migration to rename `adventure_id` → `subject_type`/`subject_id` and relocate views. Plan: land the template extraction, then submit a coordinated PR to sailing_plus that updates it to the new column names and view paths. |
| `migrajob` | **Consuming project for this work**. MigraJob is built *after* these primitives land and relies on all five of them. |

The sailing_plus migration is the only real friction point. Keep it small, keep it mechanical, and land it in a single commit.
