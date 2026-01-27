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
- **MCP**: fast-mcp gem for Model Context Protocol at `/mcp`

## MCP: Agent-Native Architecture

This app is **agent-native** - every action available in the UI is also available via MCP tools.

### Transport

Uses **Streamable HTTP** transport (recommended by MCP spec):
- Tool calls: POST to `/mcp/messages`
- Server notifications: SSE at `/mcp/sse` (optional)

### Authentication

API key authentication via `x-api-key` header (lowercase):

```bash
curl -X POST -H "Content-Type: application/json" \
  -H "x-api-key: your_api_key" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"show_current_user","arguments":{}},"id":1}' \
  http://localhost:3000/mcp/messages
```

Users get an `api_key` on creation. Regenerate with `user.regenerate_api_key!`

### Testing with MCP Inspector

```bash
# 1. Start server
bin/dev

# 2. Open MCP Inspector
npx @anthropic-ai/mcp-inspector

# 3. Configure:
#    - Transport: Streamable HTTP
#    - URL: http://localhost:3000/mcp/messages
#    - Headers: { "x-api-key": "<user-api-key>" }

# 4. Connect and test tools
```

### Available Tools

| Tool | Description | Auth Required |
|------|-------------|---------------|
| `list_chats` | List user's chats | User |
| `show_chat` | Get chat with messages | User |
| `create_chat` | Create new chat | User |
| `update_chat` | Change chat's model | User |
| `delete_chat` | Delete a chat | User |
| `list_messages` | List chat messages | User |
| `create_message` | Send message, get response | User |
| `list_models` | List available AI models | None |
| `show_model` | Get model details | None |
| `refresh_models` | Sync models from providers | Admin |
| `show_current_user` | Get current user info | User |
| `update_current_user` | Update profile | User |

### Available Resources

| Resource | URI | Description |
|----------|-----|-------------|
| Current User | `app:///user/current` | Authenticated user info |
| Available Models | `app:///models` | Enabled AI models |
| User Chats | `app:///chats` | User's chat list |
| Chat | `app:///chats/{id}` | Single chat with messages |
| Chat Messages | `app:///chats/{chat_id}/messages` | Messages only |

### File Structure

```
app/
├── tools/
│   ├── application_tool.rb      # Base class with auth helpers
│   ├── chats/                   # Chat CRUD tools
│   ├── messages/                # Message tools
│   ├── models/                  # Model tools
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
      require_authentication!

      cards = current_user.cards.limit(limit)
      success_response(cards.map { |c| serialize_card(c) })
    end

    private

    def serialize_card(card)
      { id: card.id, title: card.title }
    end
  end
end
```

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
# or: bundle exec rubocop -A && rails test && bundle exec brakeman -q
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

- **Users**: `/session/new` → auto-create on first login → `/home`
- **Admins**: `/admins/session/new` → must exist in DB → `/madmin`
- Separate interfaces, no links between them

```ruby
# Generate token
user.signed_id(purpose: :magic_link, expires_in: 15.minutes)

# Verify token
User.find_signed!(params[:token], purpose: :magic_link)
```

Helpers: `current_user`, `current_admin`, `authenticate_user!`, `authenticate_admin!`

## RubyLLM AI Chat

Working chat interface at `/chats` with OpenAI and Anthropic.

```
User → has_many :chats
Chat → belongs_to :user, belongs_to :model, acts_as_chat
Message → belongs_to :chat (role, content, tokens)
Model → model_id, provider, capabilities
```

Responses via `ChatResponseJob` (Solid Queue).

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

### Testing
- **TDD: Write tests first**
- Minitest + fixtures (no RSpec/FactoryBot)
- Fixtures use hardcoded UUIDv7 strings for IDs
- `Current.user = users(:one)` in setup

### Frontend
- Turbo Frames/Streams for updates
- Stimulus for JS sprinkles
- `inline_svg` for icons
- No npm/yarn packages
