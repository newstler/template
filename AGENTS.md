# [Project Name]

<!-- 
TEMPLATE NOTE: Replace this entire section with your actual project description.
Delete these HTML comments and write what your app does.
-->

[Describe what your application does here. This template provides Rails 8 with magic link auth, AI chat via RubyLLM, SQLite + Solid Stack, and Hotwire frontend.]

## Tech Stack

- **Ruby**: 4.0.x / **Rails**: 8.x
- **Database**: SQLite with Solid Stack (Cache, Queue, Cable)
- **Replication**: Litestream (automatic in production)
- **AI**: RubyLLM (OpenAI & Anthropic)
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS 4
- **Deployment**: Kamal 2
- **Admin**: Madmin at `/madmin`
- **Error Tracking**: Rails Error Dashboard (RED) at `/red`
- **Icons**: inline_svg gem
- **Primary Keys**: UUIDv7 (database-generated)
- **Billing**: Stripe (subscriptions, checkout, customer portal)
- **Multilingual**: Mobility gem (KeyValue backend) + RubyLLM auto-translation
- **MCP**: fast-mcp gem for Model Context Protocol at `/mcp`

## MCP: Agent-Native Architecture

This app is **agent-native** - every action available in the UI is also available via MCP tools.

### Transport

Uses **Streamable HTTP** transport (recommended by MCP spec):
- Tool calls: POST to `/mcp/messages`
- Server notifications: SSE at `/mcp/sse` (optional)

### Authentication

**Team-level API key authentication**. Teams own API keys, and users are identified via email header.

| Header | Purpose |
|--------|---------|
| `x-api-key` | Team's API key (required for all authenticated tools) |
| `x-user-email` | User's email (required for user-specific operations) |

```bash
# Team-only operation (e.g., list_models)
curl -X POST -H "Content-Type: application/json" \
  -H "x-api-key: your_team_api_key" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_models","arguments":{}},"id":1}' \
  http://localhost:3000/mcp/messages

# User-specific operation (e.g., list_chats)
curl -X POST -H "Content-Type: application/json" \
  -H "x-api-key: your_team_api_key" \
  -H "x-user-email: user@example.com" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_chats","arguments":{}},"id":1}' \
  http://localhost:3000/mcp/messages
```

Teams get an `api_key` on creation. Regenerate in Team Settings or via `team.regenerate_api_key!`

### Testing with MCP Inspector

```bash
# 1. Start server
bin/dev

# 2. Open MCP Inspector
npx @anthropic-ai/mcp-inspector

# 3. Configure:
#    - Transport: Streamable HTTP
#    - URL: http://localhost:3000/mcp/messages
#    - Headers: { "x-api-key": "<team-api-key>", "x-user-email": "<user-email>" }

# 4. Connect and test tools
```

### Available Tools

| Tool | Description | Auth Required |
|------|-------------|---------------|
| `list_teams` | List user's teams | Team + User |
| `show_team` | Get team details with members | Team + User |
| `update_team` | Update team name/currency/country | Team + User (admin) |
| `invite_member` | Invite user to team | Team + User (admin) |
| `list_chats` | List user's chats in team | Team + User |
| `show_chat` | Get chat with messages | Team + User |
| `create_chat` | Create new chat | Team + User |
| `update_chat` | Change chat's model | Team + User |
| `delete_chat` | Delete a chat | Team + User |
| `list_messages` | List chat messages | Team + User |
| `create_message` | Send message, get response | Team + User |
| `list_models` | List available AI models | None |
| `show_model` | Get model details | None |
| `refresh_models` | Sync models from providers | Admin |
| `show_current_user` | Get current user info | Team + User |
| `update_current_user` | Update profile (name, locale, preferred_currency, residence_country_code) | Team + User |
| `show_subscription` | Get team subscription status | Team + User (admin) |
| `list_prices` | List available subscription prices | None |
| `create_checkout` | Create Stripe Checkout session URL | Team + User (admin) |
| `get_billing_portal` | Get Stripe Billing Portal URL | Team + User (admin) |
| `cancel_subscription` | Cancel subscription at period end | Team + User (admin) |
| `resume_subscription` | Resume a canceled subscription before period ends | Team + User (admin) |
| `list_languages` | List all enabled languages | None |
| `list_team_languages` | List team's active languages | Team + User |
| `add_team_language` | Add language to team | Team + User (admin) |
| `remove_team_language` | Remove language from team | Team + User (admin) |
| `list_articles` | List team's articles | Team + User |
| `show_article` | Get article with full content | Team + User |
| `create_article` | Create new article | Team + User |
| `update_article` | Update article | Team + User |
| `delete_article` | Delete article | Team + User |
| `list_conversations` | List conversations the user participates in | Team + User |
| `show_conversation` | Get a conversation with recent messages | Team + User |
| `create_conversation` | Create a conversation with participants | Team + User |
| `list_conversation_messages` | List messages in a conversation | Team + User |
| `create_conversation_message` | Post a message to a conversation | Team + User |
| `show_team_dashboard` | Team dashboard KPIs + chats time-series | Team + User |
| `show_admin_dashboard` | Platform-wide admin KPIs + time-series | Admin |

**Note:** "Team + User" means both `x-api-key` (team) and `x-user-email` headers required.

### Available Resources

| Resource | URI | Description |
|----------|-----|-------------|
| Current User | `app:///user/current` | Authenticated user info |
| Available Models | `app:///models` | Enabled AI models |
| User Chats | `app:///chats` | User's chat list |
| Chat | `app:///chats/{id}` | Single chat with messages |
| Chat Messages | `app:///chats/{chat_id}/messages` | Messages only |
| Team Subscription | `app:///subscription` | Team subscription status |
| Available Languages | `app:///languages` | Enabled translation languages |
| Team Languages | `app:///team/languages` | Team's active languages (directs to tool) |
| Articles | `app:///articles` | Team's articles (directs to tool) |
| User Conversations | `app:///conversations` | User's conversations (directs to tool) |

### File Structure

```
app/
├── tools/
│   ├── application_tool.rb      # Base class with auth helpers
│   ├── articles/                # Article CRUD tools
│   ├── billing/                 # Billing & subscription tools
│   ├── chats/                   # Chat CRUD tools
│   ├── conversations/           # Conversation tools (list/show/create)
│   ├── conversation_messages/   # Conversation message tools
│   ├── dashboards/              # Team + admin dashboard aggregate tools
│   ├── languages/               # Language management tools
│   ├── messages/                # Message tools
│   ├── models/                  # Model tools
│   ├── notifications/           # Notification inbox tools
│   ├── teams/                   # Team management tools
│   └── users/                   # User tools
└── resources/
    ├── application_resource.rb  # Base class
    └── mcp/                     # MCP resources (namespaced)
```

### Agent-Native Development Rule

**Every new feature MUST have MCP parity.**

When adding new functionality:
1. Create model/controller as usual
2. Create matching MCP tool(s) in `app/tools/`
3. Create matching MCP resource(s) in `app/resources/mcp/`
4. Write tests in `test/tools/` and `test/resources/`

The app should always be fully accessible via MCP tools.

### Tool Patterns

```ruby
# app/tools/cards/list_cards_tool.rb
module Cards
  class ListCardsTool < ApplicationTool
    description "List user's cards"

    arguments do
      optional(:limit).filled(:integer).description("Max cards to return")
    end

    def call(limit: 20)
      require_user!  # Requires both x-api-key (team) and x-user-email headers

      cards = current_user.cards.where(team: current_team).limit(limit)
      success_response(cards.map { |c| serialize_card(c) })
    end

    private

    def serialize_card(card)
      { id: card.id, title: card.title }
    end
  end
end
```

**Authentication helpers:**
- `require_team!` - Only requires `x-api-key` (team API key)
- `require_user!` - Requires both `x-api-key` and `x-user-email` (user must be team member)
- `with_current_user { }` - Sets `Current.user` and `Current.team` for model callbacks

### Resource Patterns

**Note:** Resources can't authenticate in fast-mcp (no headers access). Use resources for public data or direct users to tools for authenticated access.

```ruby
# app/resources/mcp/cards_resource.rb (public data)
module Mcp
  class PublicCardsResource < ApplicationResource
    uri "app:///cards/public"
    resource_name "Public Cards"
    description "List of public cards"
    mime_type "application/json"

    def content
      to_json(Card.public_visible.map { |c| serialize_card(c) })
    end
  end
end

# app/resources/mcp/user_cards_resource.rb (directs to tool)
module Mcp
  class UserCardsResource < ApplicationResource
    uri "app:///cards"
    resource_name "User Cards"
    description "User's cards. Use list_cards tool for authenticated access."
    mime_type "application/json"

    def content
      to_json({
        message: "Use the 'list_cards' tool for authenticated card access",
        tool: "list_cards"
      })
    end
  end
end
```

## Colors

**STRICT RULE:** Use OKLCH for all custom colors.

- Custom theme colors (dark-*, accent-*) use `oklch()` format
- No hex, rgb, hsl in CSS variables or inline values
- Standard Tailwind utilities (red-500, green-400) are acceptable

## Quick Reference

```bash
bin/dev                    # Start dev server (REQUIRED)
rails console              # Console
rails test                 # Run tests
bundle exec rubocop -A     # Fix style
bin/ci                     # All quality checks
```

## Quality Gates (REQUIRED)

Before ANY commit:

```bash
bin/ci
# or: bundle exec rubocop -A && rails test && bin/brakeman --no-pager
```

All must pass. No exceptions.

## Architecture: 37signals Vanilla Rails

> "The best code is the code you don't write."

### Core Principles

1. **Fat models, thin controllers** - Business logic lives in models
2. **CRUD controllers only** - Everything is a resource
3. **Concerns for shared behavior** - Named as adjectives (Closeable, Publishable)
4. **State as records, not booleans** - `card.closure` not `card.closed`
5. **Database-backed everything** - SQLite + Solid Stack (no Redis)
6. **Build it yourself** - Before reaching for gems

### What We Avoid

- ❌ Service objects, query objects, form objects
- ❌ devise, pundit, sidekiq, redis
- ❌ view_component, GraphQL
- ❌ React/Vue/npm/yarn

### REST Mapping

Custom actions become resources:

```ruby
# ❌ POST /cards/:id/close
# ✅ POST /cards/:id/closure → Cards::ClosuresController#create
```

## Code Patterns

### Controllers (thin)

```ruby
class Cards::ClosuresController < ApplicationController
  def create
    @card = Current.user.cards.find(params[:card_id])
    @card.close
    redirect_to @card
  end
end
```

### Models (fat, with concerns)

```ruby
class Card < ApplicationRecord
  include Closeable

  belongs_to :board
  scope :open, -> { where.missing(:closure) }
  scope :chronologically, -> { order(created_at: :asc) }
end
```

### Concerns (adjectives)

```ruby
# app/models/concerns/closeable.rb
module Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, as: :closeable, dependent: :destroy
    scope :closed, -> { joins(:closure) }
    scope :open, -> { where.missing(:closure) }
  end

  def close(by: Current.user)
    create_closure!(closed_by: by)
  end

  def closed? = closure.present?
end
```

### Views

- Turbo Frames for partial updates
- Turbo Streams for real-time
- Stimulus for JS sprinkles
- `inline_svg` for icons (never inline SVG)

```erb
<%= turbo_frame_tag dom_id(@card) do %>
  <%= render @card %>
<% end %>

<%= inline_svg "icons/check.svg", class: "w-5 h-5" %>
```

## Database

### Migrations with UUIDv7

```ruby
create_table :cards, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
  t.references :board, null: false, foreign_key: true, type: :string
  t.string :title, null: false
  t.timestamps
end
```

### Fixtures

```yaml
# test/fixtures/cards.yml
# Use hardcoded UUIDv7 strings for referential integrity
one:
  id: 01961a2a-c0de-7000-8000-000000000001
  board: main
  title: "Test Card"
```

## Authentication

Magic links (passwordless):

- **Users**: `/session/new` → auto-create on first login → team context
- **Admins**: `/admins/session/new` → must exist in DB → `/madmin`
- Separate interfaces, no links between them

```ruby
# Generate token
user.signed_id(purpose: :magic_link, expires_in: 15.minutes)

# Verify token
User.find_signed!(params[:token], purpose: :magic_link)
```

Helpers: `current_user`, `current_admin`, `current_team`, `current_membership`, `authenticate_user!`, `authenticate_admin!`

## Multitenancy

Users belong to teams. Team-scoped routes live under `/t/:team_slug/...`. Authenticated users outside any team context land on the **personal** context at `/home`, which lists their teams and offers a create-team CTA (hidden once they own one). The sidebar's context switcher moves between the personal context and each team the user belongs to.

### Contexts

- **Team context** (`/t/:team_slug/...`): `current_team`, `current_membership`, team-scoped queries.
- **Personal context** (`/home`): `current_user` only, `current_team` is `nil`. Use `personal_context?` helper to branch. Stripe-dependent features hide in this context since there's no team to bill.

### URL Structure

```
/home                    → Personal dashboard (authenticated, no team)
/t/:team_slug/           → Team home
/t/:team_slug/chats      → Team's chats
/t/:team_slug/members    → Team members (admin only for invite/remove)
/t/:team_slug/settings   → Team settings (admin only)
/t/:team_slug/pricing    → Subscription pricing (admin only, Stripe-gated)
/t/:team_slug/billing    → Billing management (admin only, Stripe-gated)
/teams                   → Team selection
```

### Models

```
Team → has_many :memberships, has_many :users (through), has_many :chats
Membership → belongs_to :user, belongs_to :team (role: owner/admin/member)
User → has_many :memberships, has_many :teams (through)
Chat → belongs_to :user, belongs_to :team
```

### Access Control

```ruby
# In controllers
current_team           # The team from URL context
current_membership     # User's membership in current team
require_team_admin!    # Before action for admin-only routes

# In models
user.member_of?(team)  # Check membership
user.admin_of?(team)   # Check admin/owner role
user.owner_of?(team)   # Check owner role
membership.admin?      # admin or owner
membership.owner?      # owner only
```

### MCP Team Context

Team context is provided implicitly via the team's API key. No separate `x-team-slug` header is needed:

```bash
curl -X POST -H "Content-Type: application/json" \
  -H "x-api-key: your_team_api_key" \
  -H "x-user-email: user@example.com" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_chats","arguments":{}},"id":1}' \
  http://localhost:3000/mcp/messages
```

### Team Invitations

Reuses magic link flow with team context:

```ruby
# Generate invitation link
token = user.signed_id(purpose: :magic_link, expires_in: 7.days)
invite_url = verify_magic_link_url(token: token, team: team.slug, invited_by: inviter.id)

# Link creates membership on verification
UserMailer.team_invitation(user, team, inviter, invite_url).deliver_later
```

## RubyLLM AI Chat

Working chat interface at `/chats` with OpenAI and Anthropic.

```
User → has_many :chats
Chat → belongs_to :user, belongs_to :model, acts_as_chat
Message → belongs_to :chat (role, content, tokens)
Model → model_id, provider, capabilities
```

Responses via `ChatResponseJob` (Solid Queue).

## Multilingual Content

Automatic translation of user-generated content via LLM. Uses the Mobility gem (KeyValue backend) for storage and RubyLLM for translation.

```
Language → code, name, native_name, enabled
TeamLanguage → team, language, active (join model)
Translatable → concern for auto-translation
TranslateContentJob → LLM translation via the model configured in Madmin at Setting.translation_model
BackfillTranslationsJob → translate existing content when language added
```

### Making a Model Translatable

```ruby
class Article < ApplicationRecord
  include Translatable
  belongs_to :team
  translatable :title, type: :string
  translatable :body, type: :text
end
```

See `.claude/rules/multilingual.md` for full conventions.

### Adding a New Language

To add support for a language that isn't already in `config/locales/`:

1. **Add language-name stubs** to `config/locales/en.yml` and `config/locales/ru.yml` under the `languages:` key, using the ISO 639-1 code and the localized name:
   ```yaml
   en:
     languages:
       xx: "Example Language"
   ru:
     languages:
       xx: "Пример языка"
   ```
2. **Create the full locale file** at `config/locales/xx.yml` and per-view/mailer files under `config/locales/xx/`. Follow the existing structure of `config/locales/en/` as the canonical layout. The top-level `xx.yml` must define `language_name` and `native_name` so `Language.sync_from_locale_files!` can create the record.
3. **Run the language sync** to populate the `Language` model:
   ```bash
   bin/rails runner 'Language.sync_from_locale_files!'
   ```
4. **Enable the language** via Madmin at `/madmin/languages` (admin action) or per-team at `/t/:slug/languages`.
5. **Verify pluralization rules** — Russian and several Slavic languages have the `one/few/many/other` rule; Arabic has `zero/one/two/few/many/other`. Rails i18n handles these natively if the YAML file defines all the forms.

The template ships language-name stubs for `en, de, es, fr, ru` (full content) and `tg, uz, ky, tr, sr` (stubs only — add content when a consuming project needs them).

### Pluralization Example (Russian)

```yaml
ru:
  candidates:
    count:
      one:   "%{count} кандидат"
      few:   "%{count} кандидата"
      many:  "%{count} кандидатов"
      other: "%{count} кандидата"
```

Always use `t("key", count: n)` (not string interpolation) for any countable noun.

## Notifications

User-facing notifications via [Noticed v2](https://github.com/excid3/noticed). Database + email delivery shipped; Slack, Twilio, Vonage, web/mobile push available as opt-in adapters when a consuming app needs them.

### Declaring a Notifier

```ruby
# app/notifiers/deal_confirmed_notifier.rb
class DealConfirmedNotifier < ApplicationNotifier
  deliver_by :email do |config|
    config.mailer = "NotificationMailer"
    config.method = :deal_confirmed
    config.if     = -> { recipient.wants_notification?(kind: :deal_confirmed_notifier, channel: :email) }
  end

  notification_methods do
    def message
      I18n.t("notifiers.deal_confirmed_notifier.message", title: record.title)
    end

    def url
      Rails.application.routes.url_helpers.deal_path(record)
    end
  end
end
```

Subclass `ApplicationNotifier`, not `Noticed::Event` directly — the Turbo Stream broadcast hook is registered globally on `Noticed::Event` via `config/initializers/noticed_broadcasts.rb`.

### Triggering a notification

```ruby
DealConfirmedNotifier.with(record: deal).deliver(recipient)
# → creates noticed_event + noticed_notification rows (persistence is automatic in v2)
# → renders the email via NotificationMailer#deal_confirmed (respects user preferences)
# → broadcasts a Turbo Stream prepend to [recipient, :notifications]
```

### Reading the inbox

```ruby
current_user.notifications              # has_many :notifications via Notifiable concern
current_user.notifications.unread       # provided by Noticed
current_user.notifications.mark_as_read # bulk mark-read
```

### User preferences

`User#notification_preferences` is a JSON column with the shape:

```ruby
{ "welcome_notifier" => { "email" => false, "database" => true } }
```

Missing keys mean opt-in (default behavior). Preferences are checked via `user.wants_notification?(kind:, channel:)` inside each Notifier's `deliver_by :if` block.

### Live updates

Any page that renders `<%= turbo_stream_from current_user, :notifications %>` will update live when a new notification arrives. Pages without the helper are unaffected.

### Audit trail

- `/madmin/noticed_events` — every event that was triggered, with its type, record, and params
- `/madmin/noticed_notifications` — every delivery record, with recipient and read/seen state

### File structure

```
app/
├── notifiers/
│   ├── application_notifier.rb            # Base class (subclass this, not Noticed::Event)
│   ├── welcome_notifier.rb                # Reference notifier
│   └── [domain notifiers]
├── models/concerns/
│   └── notifiable.rb                      # Recipient concern — wants_notification? helper
├── mailers/
│   └── notification_mailer.rb             # One method per notifier using :email delivery
└── views/
    ├── notification_mailer/
    │   └── [method].{html,text}.erb       # One per notifier
    └── notifications/
        ├── index.html.erb                 # Inbox
        ├── _notification.html.erb         # Row wrapper — dispatches by kind
        └── kinds/
            └── _[kind].html.erb           # Per-notifier UI partial

config/initializers/
└── noticed_broadcasts.rb                  # Turbo Stream broadcast hook on Noticed::Event
```

### Rule: no service-layer notification helpers

Do not wrap `Notifier.with(...).deliver(recipient)` in a service method. The Notifier class *is* the service — calling it from a controller action or model callback is the pattern. If you find yourself wanting a `NotificationService`, that's a sign the Notifier class itself should absorb the logic.

## Conversations

Team-scoped person-to-person messaging at `/t/:slug/conversations/:id`. Distinct from RubyLLM AI chat (`/chats`), which is user-to-LLM.

### Models

- `Conversation` — belongs to `Team`, optional polymorphic `subject` (e.g. a `Deal`, `Request`, or `nil` for a team-general thread)
- `ConversationParticipant` — join model with `last_read_at` / `last_notified_at` for read/notified tracking
- `ConversationMessage` — `content` (nullable, allows attachment-only), `body_translations` JSON, `flagged_at`, `flag_reason`, Active Storage `attachments`

### Creating a conversation

```ruby
conversation = Conversation.find_or_create_for(
  team: team,
  subject: deal,
  participants: [agency_user, employer_user]
)
```

### Opt-in concerns

```ruby
class ConversationMessage < ApplicationRecord
  include TranslatableMessage   # auto-translate content to each participant's locale
  include ModeratableMessage    # regex + LLM moderation for contact-leak detection
end
```

Both concerns are opt-in because they require configured models (`Setting.translation_model`, `Setting.moderation_model` — both editable at `/madmin/ai_models`). Apps that don't need them simply don't include the concerns.

### Live updates

`<%= turbo_stream_from @conversation %>` in the view enables live updates. Every new `ConversationMessage` is appended to `#conversation_messages` automatically via `after_create_commit :broadcast_append_to_conversation`.

### Read tracking

`ConversationParticipant#mark_as_read!` updates `last_read_at`. The controller calls it in `#show` so visiting the conversation marks it read. `ConversationDigestNotificationJob` throttles email digests to at most one per participant every 5 minutes.

### Notification jobs

- `ConversationNotificationJob` — immediate per-message email to each non-sender participant
- `ConversationDigestNotificationJob` — debounced digest (runs 2 minutes after a message is posted, skips recipients notified in the last 5 minutes)

The `ConversationMessage` model uses the digest job by default; swap to the immediate job where single-message alerts are desired.

## Currencies + Countries

Every team-scoped app uses the same primitives.

### Money

- `CurrencyConvertible` concern holds constants (`SUPPORTED_CURRENCIES`, `POPULAR_CURRENCIES`, `CURRENCY_NAMES`, `COUNTRY_CURRENCY`) and a `convert_amount(cents, from, to)` helper backed by Money's CurrencyLayer bank.
- `Current.currency` is set on every request via the detection chain:
  1. `current_user.preferred_currency`
  2. Signed cookie `tmpl_currency`
  3. IP → country → currency mapping via `CurrencyConvertible::COUNTRY_CURRENCY`
  4. `current_team.default_currency`
  5. `Setting.default_currency` (platform default)
- Daily `RefreshCurrencyRatesJob` (recurring, 04:00 UTC) warms `Money.default_bank`'s file cache so no request blocks on a CurrencyLayer API call.
- `format_amount(value)` uses the current locale's delimiter (English `1,000,000`, Russian `1 000 000`).
- Settings editable in Madmin at `/madmin/ai_models`: `currencylayer_api_key`, `default_currency`, `default_country_code`.

### Country

```ruby
class Team < ApplicationRecord
  include Countryable
  countryable :country_code
end

team.country        # => ISO3166::Country instance or nil
team.country_name   # => localized name
team.country_flag   # => emoji flag ("🇩🇪")
```

Helpers: `country_name(code)`, `country_flag(code)`, `country_options_for_select(selected, include_blank:, countries:)`.

Partial: `<%= render "shared/country_select", form: f, method: :country_code %>` for a searchable dropdown with flag emojis.

### MCP tools

- `update_current_user_tool` accepts `preferred_currency` and `residence_country_code`.
- `update_team_tool` (admin only) accepts `name`, `default_currency`, `country_code`.

### Rule

Currency codes are always ISO 4217 strings (3 uppercase letters). Country codes are always ISO 3166 alpha-2 (2 uppercase letters). Monetary amounts in the database are always integer cents.

## Searchable (Full-Text Search)

SQLite FTS5 via a concern. Zero external dependencies.

### Declaring

```ruby
class Candidate < ApplicationRecord
  include Searchable
  searchable_fields :profession, :specialization, :skills, :languages, :notes
end
```

Each declared field is synced into a sibling FTS5 virtual table (`<table>_fts`) on every `after_save_commit` and scrubbed on `after_destroy_commit`.

### Installing the FTS virtual table

```bash
bin/rails generate searchable:install Candidate profession specialization skills languages notes
bin/rails db:migrate
```

The generator emits a `create_virtual_table` migration using the tokenizer from `Setting.search_tokenizer` (default `"porter unicode61 remove_diacritics 2"`).

### Querying

```ruby
Candidate.search("welder russian speaker")
# => relevance-ordered ActiveRecord::Relation (bm25)
# => handles Cyrillic and Turkish diacritics via unicode61
```

Composable with other scopes:

```ruby
Candidate.search("welder").where(status: :active).limit(20)
```

`.search` returns a true `ActiveRecord::Relation`, so `.where`, `.includes`, `.limit`, `.order`, and pagination all compose naturally. Blank or nil queries return `.none`.

### Reindexing

```bash
bin/rails 'fts:rebuild[Candidate]'
```

Use this after changing the tokenizer setting or backfilling existing data.

### Tokenizer

Controlled by `Setting.search_tokenizer`, editable in Madmin at `/madmin/ai_models`. Default `"porter unicode61 remove_diacritics 2"`:

- `porter` — stemming (welder → weld)
- `unicode61` — Unicode word segmentation
- `remove_diacritics 2` — fold Latin diacritics (Çilingir → cilingir)

Tokenizer changes only affect new rows. Run `fts:rebuild` to re-index existing rows.

### Limitations (acceptable at template scale)

- Two-step query (FTS id lookup → records) rather than a single JOIN, so string PKs stay supported.
- No phrase queries unless the user escapes quotes (the concern sanitizes stray quotes into whitespace).
- No facets — compose with `.where` scopes instead.
- Public API is stable enough to swap to Meilisearch/Typesense under the hood without touching callers.

## Embeddable + RAG Kit

Vector search and semantic retrieval via [sqlite-vec](https://github.com/asg017/sqlite-vec), a loadable SQLite extension with zero runtime dependencies. Binaries for `linux-x86_64`, `linux-aarch64`, and `darwin-arm64` are vendored at `vendor/sqlite-vec/` and loaded on every new SQLite connection via `lib/sqlite_vec.rb` (wired into `config/database.yml`'s `extensions:` array).

### Basic similarity search

```ruby
class Candidate < ApplicationRecord
  include Embeddable

  embeddable_source ->(r) { "#{r.profession} #{r.skills} #{r.experience_summary}" }
  embeddable_model  -> { Setting.embedding_model }
  embeddable_distance :cosine
end

Candidate.similar_to("welder with marine experience", limit: 20)
# → ActiveRecord::Relation of Candidates ordered by vec0 distance ascending
# → each record exposes #similarity_distance for UI display
# → composable with .where / .includes
```

### Metadata pre-filtering

Declare metadata columns in the vec0 table (via the generator's `--metadata` option). Then filter before KNN:

```ruby
embeddable_metadata ->(r) { { nationality: r.nationality_code, years_experience: r.experience_years } }

Candidate.similar_to("welder", filter_by: { nationality: "UZ", years_experience: 3..10 })
# → WHERE nationality = 'UZ' AND years_experience BETWEEN 3 AND 10 → KNN
```

Supported filter types: scalar, `Range`, and `Array` (IN).

### Hybrid search (keyword + semantic)

```ruby
class Candidate < ApplicationRecord
  include Searchable
  include Embeddable
  include HybridSearchable
end

Candidate.hybrid_search("welder marine experience", limit: 20)
# → FTS5 bm25 + vector KNN, fused via Reciprocal Rank Fusion (k = Setting.rrf_k)
# → score(id) = Σ 1 / (k + rank) across both result lists
# → RRF sidesteps the score-normalization problem between bm25 and cosine similarity
```

### Chunking long documents

```ruby
class Article < ApplicationRecord
  include Embeddable
  include Chunkable
  chunk_source ->(r) { r.body }
  chunk_size 400     # words per chunk
  chunk_overlap 40   # words carried into the next chunk
end
```

Chunks live in the polymorphic `chunks` table and each chunk includes `Embeddable`, so they get their own vec0 rows in `chunks_embeddings`. Rechunking runs in `after_save_commit` only when the SHA256 of the source changes.

### Installation

```bash
bin/rails generate embeddable:install Candidate 1536 --metadata nationality profession
bin/rails db:migrate
bin/rails 'embeddings:rebuild[Candidate]'
```

### Settings (editable in Madmin at `/madmin/ai_models`)

- `Setting.embedding_model` — default `"text-embedding-3-small"`
- `Setting.rrf_k` — default `60` (Cormack et al. SIGIR 2009 standard)

### Caching

- Re-embedding is skipped when the SHA256 of the source string is unchanged (compared against `source_hash` in the vec0 row before enqueuing `EmbedRecordJob`).
- Metadata pre-filtering via `filter_by:` is always WHERE-before-KNN, cheaper than post-filtering.

### Deployment

When deploying a consuming app with sqlite-vec, ensure `vendor/sqlite-vec/` is copied into the container. The template's `Dockerfile` already does this via `COPY . .`; if a consuming app has its own Dockerfile, replicate that line (or add an explicit `COPY vendor/sqlite-vec vendor/sqlite-vec`).

### Out of scope

- External vector databases (Pinecone, Weaviate, pgvector)
- Re-ranking models (Cohere Rerank)
- Query expansion (HyDE, multi-query)

The public API (`similar_to`, `hybrid_search`, `include Embeddable`) is stable enough to swap the concern's implementation without touching call sites.

## Dashboards

Chartkick + Groupdate with a shared `DashboardHelper` module and reusable partials. The reference team dashboard is the root of every team (`/t/:slug/`); the admin dashboard is the Madmin root (`/madmin`).

### Basic pattern

```erb
<%= kpi_card label: t(".users"), value: @user_count, trend: pct_change(@recent, @prev) %>

<%= render "shared/chart_card", title: t(".growth") do %>
  <%= line_chart @users_timeline %>
<% end %>

<%= attention_items_strip(@attention_items) %>
```

### Time-range selector

```erb
<select data-controller="time-range" data-action="change->time-range#update">
  <option value="7d">Last 7 days</option>
  <option value="30d" selected>Last 30 days</option>
  <option value="90d">Last 90 days</option>
</select>
```

In the controller: `@range = time_range_from(params[:range])` → use `@range` in `.where(created_at: @range)` queries and `.group_by_day(:created_at, range: @range)` for time-series.

### Caching

```ruby
@top_users = cached_dashboard(:top_users, expires_in: 10.minutes) do
  current_team.users.joins(:chats).group("users.id")
              .order(Arel.sql("SUM(chats.total_cost) DESC")).limit(10).to_a
end
```

Cache key includes team id + key + range begin, so invalidation is automatic on range change.

### Partials

- `shared/kpi_card` — label, value, optional trend, optional icon, optional link
- `shared/chart_card` — wraps a Chartkick chart with title + `chart-theme` Stimulus controller
- `shared/attention_items_strip` — color-coded action badges
- `shared/progress_ring` — SVG circular progress indicator

### Helpers (`DashboardHelper`)

- `kpi_card(label:, value:, trend:, icon:, href:)`
- `pct_change(current, previous)` — nil-safe
- `trend_arrow(delta)` — returns ↑ ↓ →
- `sparkline(series, width:, height:)` — tiny inline SVG line chart
- `progress_ring(value:, max:, size:, label:)`
- `attention_items_strip(items)`
- `cached_dashboard(key, expires_in:, &block)`
- `time_range_from(param)` — returns a `Range`

### Stimulus controllers

- `chart_theme` — OKLCH-aware themer for Chartkick/Chart.js canvases
- `sparkline` — hover tooltips on the inline SVG sparklines
- `time_range` — posts `?range=` back via `Turbo.visit` when the selector changes

### Rules (enforced)

See `.claude/rules/performance.md` § Dashboards.

## Testing

Minitest + fixtures only (no RSpec, no FactoryBot):

```ruby
class CardTest < ActiveSupport::TestCase
  setup do
    Current.user = users(:one)
  end

  test "can be closed" do
    card = cards(:one)
    assert_not card.closed?
    card.close
    assert card.closed?
  end
end
```

## File Structure

```
app/
├── controllers/
│   ├── concerns/
│   ├── sessions_controller.rb
│   ├── chats_controller.rb
│   ├── admins/sessions_controller.rb
│   └── madmin/
├── models/
│   ├── concerns/
│   ├── current.rb
│   └── [domain models]
├── views/
└── jobs/

app/javascript/controllers/   # Stimulus only
app/assets/images/icons/      # SVG for inline_svg
```

## Credentials

API keys (AI, Stripe, SMTP, Litestream) are managed in the admin panel at `/madmin/settings`.

Rails encrypted credentials are used only for secrets that need to be available during Docker build:

```bash
rails credentials:edit --environment production
```

```yaml
# MaxMind GeoLite2 for IP geolocation (optional, for Nullitics analytics)
maxmind:
  account_id: "123456"
  license_key: "abc..."
```

## Test-Driven Development

**Write tests first, then implementation.**

### TDD Cycle

1. **Red**: Write a failing test for the desired behavior
2. **Green**: Write minimal code to make it pass
3. **Refactor**: Clean up while keeping tests green

### Workflow

```ruby
# 1. Start with a test
test "user can close a card" do
  card = cards(:open)
  assert_not card.closed?
  
  card.close
  
  assert card.closed?
  assert_equal Current.user, card.closure.closed_by
end

# 2. Run it - it fails (Red)
# 3. Implement the feature
# 4. Run it - it passes (Green)
# 5. Refactor if needed
```

### What to Test First

| Feature Type | Test First |
|--------------|------------|
| Model method | Unit test for the method |
| New endpoint | Integration test for request/response |
| User flow | System test with Capybara |
| Bug fix | Test that reproduces the bug |

### Test Naming

Tests describe behavior, not implementation:

```ruby
# ✅ Good - describes behavior
test "closing a card creates a closure record"
test "user cannot close cards they don't own"

# ❌ Bad - describes implementation  
test "close method calls create_closure!"
test "Closeable concern is included"
```

## Codebase Patterns

Quick reference for working in this codebase:

### Authentication
- Magic links via `signed_id` / `find_signed!`
- `Current.user` for request context
- Separate user/admin auth flows

### Models
- UUIDv7 primary keys (database-generated)
- Concerns for shared behavior (adjectives)
- State as records, not booleans
- Scopes over class methods

### Controllers
- CRUD only, nested resources for actions
- Thin - delegate to models
- `before_action :authenticate_user!`
- **Always `includes()` associations** accessed in views

### Performance (STRICT)
- **Eager load** associations accessed in loops/views (`includes(:messages)`)
- **Counter caches** over `.count` (use `chat.messages_count` not `chat.messages.count`)
- **Collection rendering** over `.each` + `render` (`render partial: collection:`)
- **Ruby methods on preloaded data** (`.find { }` not `.find_by`, `.sum(&:col)` not `.sum(:col)`)
- **Single-pass iteration** (`partition`/`group_by` not multiple `select`)
- **Bulk operations** (`insert_all`, `perform_all_later` over loops)
- **Lazy Turbo Frames** for below-the-fold content
- See `.claude/rules/performance.md` for full details

### Testing
- **TDD: Write tests first**
- Minitest + fixtures (no RSpec/FactoryBot)
- Fixtures use hardcoded UUIDv7 strings for IDs
- `Current.user = users(:one)` in setup

### Multilingual
- `include Translatable` + `translatable :attr, type: :string` on models with `team_id`
- Mobility KeyValue backend (shared polymorphic tables)
- Auto-translation via `TranslateContentJob` on create/update
- `BackfillTranslationsJob` when team adds a language
- English always required, cannot be disabled

### Frontend
- Turbo Frames/Streams for updates
- Stimulus for JS sprinkles
- `inline_svg` for icons
- No npm/yarn packages

## Nothing hardcoded: all LLM models are Madmin-configurable

**Rule:** No code in `app/` may reference a specific LLM model name as a string literal. Every LLM model name must come from a `Setting` key, editable in Madmin at `/madmin/ai_models`.

Allowed:
- `Setting.translation_model`
- `Setting.default_model`
- `Setting.embedding_model` (added by Embeddable primitive)
- `Setting.moderation_model` (added by Conversations primitive)

Not allowed:
- `RubyLLM.chat(model: "gpt-4.1-nano")` ← replace with `Setting.translation_model`
- Hardcoded model fallbacks in rescue blocks ← use `Setting` everywhere, fail loudly if unset

Fixture defaults (`test/fixtures/settings.yml`) may contain concrete model names — those are development defaults, not production constants.
