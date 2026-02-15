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
| `update_current_user` | Update profile | Team + User |
| `show_subscription` | Get team subscription status | Team + User (admin) |
| `list_prices` | List available subscription prices | None |
| `create_checkout` | Create Stripe Checkout session URL | Team + User (admin) |
| `get_billing_portal` | Get Stripe Billing Portal URL | Team + User (admin) |
| `cancel_subscription` | Cancel subscription at period end | Team + User (admin) |
| `list_languages` | List all enabled languages | None |
| `list_team_languages` | List team's active languages | Team + User |
| `add_team_language` | Add language to team | Team + User (admin) |
| `remove_team_language` | Remove language from team | Team + User (admin) |
| `list_articles` | List team's articles | Team + User |
| `show_article` | Get article with full content | Team + User |
| `create_article` | Create new article | Team + User |
| `update_article` | Update article | Team + User |
| `delete_article` | Delete article | Team + User |

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

### File Structure

```
app/
├── tools/
│   ├── application_tool.rb      # Base class with auth helpers
│   ├── chats/                   # Chat CRUD tools
│   ├── messages/                # Message tools
│   ├── models/                  # Model tools
│   ├── billing/                 # Billing & subscription tools
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

Users belong to teams. All user-facing routes are team-scoped under `/t/:team_slug/...`.

### URL Structure

```
/t/:team_slug/           → Team home
/t/:team_slug/chats      → Team's chats
/t/:team_slug/members    → Team members (admin only for invite/remove)
/t/:team_slug/settings   → Team settings (admin only)
/t/:team_slug/pricing    → Subscription pricing (admin only)
/t/:team_slug/billing    → Billing management (admin only)
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
TranslateContentJob → LLM translation via gpt-4.1-nano
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

```bash
rails credentials:edit --environment development
```

```yaml
secret_key_base: ...
openai:
  api_key: sk-...
anthropic:
  api_key: sk-ant-...
stripe:
  secret_key: sk_...
  publishable_key: pk_...
  webhook_secret: whsec_...
litestream:  # optional
  replica_bucket: ...
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
