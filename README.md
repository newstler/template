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
- **Analytics**: [Nullitics](https://nullitics.com) with [MaxMind](https://www.maxmind.com) geolocation
- **Admin Panel**: Madmin
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
  - 20+ tools for chats, messages, models, billing, teams, and users
- **Agent-native architecture** — agents have full parity with human users

### Platform

- **Magic Link Authentication** for users and admins
  - Users: First magic link creates account, subsequent ones sign in
  - Admins: Only existing admins can create new admins
- **Team-Based Multitenancy** with configurable single/multi-tenant modes
  - Roles: owner, admin, member
  - Team-scoped routes under `/t/:team_slug/`
- **Stripe Billing** with subscriptions, checkout, and customer portal
- **Litestream SQLite Replication** to S3-compatible storage (optional)
  - Continuous backup of all databases (main, cache, queue, cable)
- **UUIDv7 Primary Keys** for better distributed system support
- **Solid Stack** for production-ready background jobs, caching, and cable
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
3. Sets up AI API keys (OpenAI, Anthropic) for dev/prod
4. Optionally configures Litestream for SQLite replication
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

Admins must be created by other admins:

1. First admin is created via `rails db:seed` (update email in `db/seeds.rb`)
2. Existing admins can create new admins at `/admins/admins`
3. New admin receives magic link via email
4. Admin signs in at `/admins/session/new`

### Admin Access

- Admin panel: `/madmin`
- Admin login: `/admins/session/new`

Only authenticated admins can access Madmin.

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

This template follows [37signals vanilla Rails philosophy](https://dev.37signals.com/) and patterns from [Layered Design for Ruby on Rails Applications](https://www.packtpub.com/product/layered-design-for-ruby-on-rails-applications/9781801813785):

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
│   ├── sessions_controller.rb        # User auth
│   └── admins/
│       ├── sessions_controller.rb    # Admin auth
│       └── admins_controller.rb      # Admin management
├── models/
│   ├── user.rb                       # User model
│   └── admin.rb                      # Admin model
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

This project uses Rails encrypted credentials exclusively. No environment variables are used.

```bash
# Edit credentials
rails credentials:edit --environment development
rails credentials:edit --environment production
```

Example structure:

```yaml
secret_key_base: <auto-generated>

# Litestream (optional, configured via bin/setup wizard)
litestream:
  replica_bucket: my-app-backups
  replica_key_id: AKIAIOSFODNN7EXAMPLE
  replica_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Other services (Stripe, OpenAI, Anthropic, etc.)
stripe:
  secret_key: sk_test_...
  webhook_secret: whsec_...
```

### Litestream - SQLite Replication

Litestream provides continuous replication of all SQLite databases to S3-compatible storage:

**Setup options:**
1. During `bin/setup` configuration wizard (easiest)
2. Manually edit credentials: `rails credentials:edit --environment production`

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

Built by [Yuri Sidorov](https://yurisidorov.com) following best practices from:
- [37signals](https://37signals.com/)
- [Layered Design for Ruby on Rails Applications](https://www.packtpub.com/product/layered-design-for-ruby-on-rails-applications/9781801813785)
