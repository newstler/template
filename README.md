# AI-Native Rails Template

A modern Rails template for building AI-powered apps — with built-in chat, MCP tools, multi-provider LLM support, and agent-native architecture. Follows 37signals' vanilla Rails philosophy.

## Tech Stack

- **Ruby** 4.0.x / **Rails** (edge)
- **AI**: RubyLLM (OpenAI, Anthropic) with streaming chat
- **MCP**: Model Context Protocol server via fast-mcp
- **Database**: SQLite with Solid Stack (Cache, Queue, Cable)
- **Replication**: Litestream (SQLite → S3-compatible storage)
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS 4
- **Billing**: Stripe (subscriptions, checkout, customer portal)
- **Deployment**: Kamal 2
- **Authentication**: Magic Links (passwordless)
- **Multitenancy**: Team-based with roles (owner/admin/member)
- **Multilingual**: Mobility gem with RubyLLM auto-translation
- **Currencies**: `money` + `money-currencylayer-bank` (daily rate refresh)
- **Countries**: `countries` (iso3166) with emoji flags
- **Analytics**: [Nullitics](https://nullitics.com) with [MaxMind](https://www.maxmind.com) geolocation (optional)
- **Admin Panel**: Madmin
- **Error Tracking**: Rails Error Dashboard (RED) at `/red`
- **Notifications**: [Noticed v2](https://github.com/excid3/noticed)
- **Search**: SQLite FTS5 via the `Searchable` concern (Unicode61, bm25)
- **Primary Keys**: UUIDv7 (sortable, distributed-friendly)

## Features

### AI & Agent-Native

- **AI Chat** with OpenAI and Anthropic models
  - Streaming responses via Turbo Streams
  - Model switching per chat
  - Token tracking and cost estimation
- **MCP Server** — every UI action is also available as an MCP tool
  - Streamable HTTP transport at `/mcp/messages`
  - Team-level API key authentication
  - 30+ tools for chats, messages, models, billing, teams, users, articles, and languages
- **Agent-native architecture** — agents have full parity with human users

### Platform

- **Magic Link Authentication** for users and admins
  - Users: First magic link creates account, subsequent ones sign in
  - Admins: Only existing admins can create new admins (via Madmin)
- **Team-Based Multitenancy** with configurable single/multi-tenant modes
  - Roles: owner, admin, member
  - Team-scoped routes under `/t/:team_slug/`
- **Multilingual Content** with automatic LLM translation
  - Per-team language management
  - Auto-translates user-generated content (articles, etc.) on save
- **Stripe Billing** with subscriptions, checkout, and customer portal
- **Litestream SQLite Replication** to S3-compatible storage (optional)
  - Continuous backup of all databases (main, cache, queue, cable)
- **UUIDv7 Primary Keys** for better distributed system support
- **Solid Stack** for production-ready background jobs, caching, and cable
- **Notifications** (via Noticed v2)
  - Database + email delivery out of the box
  - Live-updating inbox via Turbo Streams
  - Per-kind, per-channel user preferences
  - Ready for Slack, SMS, web/mobile push as opt-in adapters
  - Full audit trail in Madmin at `/madmin/noticed_events`
- **Currencies + Countries**
  - Money gem with daily rate refresh from CurrencyLayer
  - Per-team default currency, per-user preferred currency
  - Per-team and per-user country (ISO 3166) with emoji flag picker
  - Locale-aware amount formatting (Russian: `1 000 000`; English: `1,000,000`)
  - `Current.currency` set on every request via a 5-step detection chain
- **Full-Text Search** via SQLite FTS5
  - `include Searchable` on any model, declare `searchable_fields`
  - Unicode61 tokenizer handles Cyrillic, Turkish, and Latin diacritics out of the box
  - Composable `Model.search(query)` returns a relevance-ordered `ActiveRecord::Relation`
  - Zero external services — SQLite ships with FTS5 built in
- **Team Messaging** (Conversations)
  - Team-scoped person-to-person chat with attachments
  - Polymorphic `subject` — attach conversations to any record
  - Live updates via Turbo Streams
  - Opt-in message translation (`TranslatableMessage` concern)
  - Opt-in contact-leak moderation (`ModeratableMessage` concern)
  - Email digests grouped by conversation with anti-spam throttling
- **Vanilla Rails** approach — no unnecessary abstractions

## Getting Started

### Clone for a New Project

```bash
# Clone this template
git clone git@github.com:newstler/template.git my_new_project
cd my_new_project

# Setup project (runs configuration wizard on first run)
bin/setup
```

On first run, `bin/setup` will launch the configuration wizard that:
1. Renames the project from "Template" to your project name
2. Configures deployment domain and admin email
3. Optionally enables Nullitics analytics
4. Consolidates migrations into a single initial schema
5. Renames git origin to `template` and asks for your repo URL
6. Commits all configuration changes
7. Installs dependencies, prepares database, and starts dev server

### Pull Template Updates

```bash
# Pull latest changes from template
git fetch template
git merge template/main

# Or cherry-pick specific commits
git cherry-pick <commit-hash>
```

## Authentication System

### User Authentication

Users can sign up and sign in using magic links sent to their email:

1. Visit `/session/new`
2. Enter email address
3. Receive magic link via email (creates account on first use)
4. Click link to sign in

### Admin Authentication

Admins are managed via the Madmin admin panel:

1. First admin is created via `rails db:seed` (email configured during `bin/setup`)
2. Existing admins can create new admins at `/madmin/admins`
3. New admin receives magic link via email
4. Admin signs in at `/admins/session/new`

### Admin Access

- Admin panel: `/madmin`
- Error dashboard: `/red` (Rails Error Dashboard)
- Admin login: `/admins/session/new`

Only authenticated admins can access Madmin and the error dashboard.

## Development

```bash
# Start dev server (Procfile.dev)
bin/dev

# Console
rails console

# Database
rails db
rails db:migrate
rails db:seed

# Tests
rails test
rails test test/models/user_test.rb:42

# Code quality
bundle exec rubocop -A

# Reconfigure project (delete .configured first)
rm .configured && bin/setup
```

## Architecture Principles

This template follows [37signals vanilla Rails philosophy](https://dev.37signals.com/):

- **Rich domain models** over service objects
- **CRUD controllers** - everything is a resource
- **Concerns** for horizontal code sharing
- **Grow into abstractions** - don't create empty directories
- **Ship to learn** - prototype quality is valid

See [CLAUDE.md](./CLAUDE.md) for complete guidelines.

## Project Structure

```
app/
├── controllers/
│   ├── sessions_controller.rb        # User auth (magic links)
│   ├── chats_controller.rb           # AI chat
│   ├── articles_controller.rb        # Multilingual articles
│   ├── home_controller.rb            # Team dashboard
│   ├── onboardings_controller.rb     # First-time user setup
│   ├── profiles_controller.rb        # User profile
│   ├── admins/
│   │   └── sessions_controller.rb    # Admin auth
│   ├── teams/                        # Team management
│   │   ├── settings_controller.rb
│   │   ├── members_controller.rb
│   │   ├── pricing_controller.rb
│   │   ├── billing_controller.rb
│   │   └── languages_controller.rb
│   └── madmin/                       # Admin panel overrides
├── models/
│   ├── user.rb, admin.rb, team.rb    # Core models
│   ├── chat.rb, message.rb, model.rb # AI chat
│   ├── article.rb, language.rb       # Multilingual content
│   ├── membership.rb                 # Team membership
│   └── concerns/                     # Shared behavior
├── tools/                            # MCP tools
├── resources/                        # MCP resources
├── mailers/
│   ├── user_mailer.rb                # User magic links
│   └── admin_mailer.rb               # Admin magic links
└── views/
```

## Deployment

Using Kamal 2:

```bash
# Update config/deploy.yml with your settings
kamal setup
kamal deploy
```

See `config/deploy.yml` for configuration.

## Configuration & Credentials

API keys (AI, Stripe, SMTP, Litestream) are managed in the admin panel at `/madmin/settings`.

For credentials that must be encrypted (e.g. MaxMind geolocation keys), use Rails credentials:

```bash
rails credentials:edit --environment development
rails credentials:edit --environment production
```

```yaml
# MaxMind GeoLite2 for IP geolocation (optional, for Nullitics analytics)
maxmind:
  account_id: "123456"
  license_key: "abc..."
```

### Litestream - SQLite Replication

Litestream provides continuous replication of all SQLite databases to S3-compatible storage:

**Setup:** Configure S3-compatible credentials in the admin panel at `/madmin/settings`.

**What gets replicated:**
- Main database
- Solid Cache
- Solid Queue
- Solid Cable

**Commands:**
```bash
rails litestream:replicate  # Start replication
rails litestream:restore    # Restore from backup
```

See `config/litestream.yml` for full configuration and [CLAUDE.md](./CLAUDE.md) for details.

## License

MIT

## Credits

Built by [Yuri Sidorov](https://yurisidorov.com) following best practices from [37signals](https://37signals.com/).
