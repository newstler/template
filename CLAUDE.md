# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

This is a Rails 8 template with magic link authentication for users and admins. The project is designed to be cloned and configured for new projects using `bin/configure`.

### First-Time Setup

When starting a new project from this template:

1. Clone the repo: `git clone git@github.com:newstler/template.git my_project`
2. Run configuration: `bin/configure`
3. The script will:
   - Rename project from "Template" to your project name
   - Ask for admin email (written directly to db/seeds.rb)
   - Optionally configure Litestream for SQLite replication
   - Run `bin/setup` to install dependencies and setup database

### Tech Stack

- **Ruby**: 4.0.x
- **Rails**: 8.x
- **Database**: SQLite with Solid Stack
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **Replication**: Litestream (SQLite → S3-compatible storage)
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS 4
- **Asset Pipeline**: Propshaft
- **Deployment**: Kamal 2

## Development Commands

### Server Management
```bash
bin/dev                           # Start dev server (REQUIRED - not rails server)
tail -f log/development.log       # Monitor logs
```

### Database
```bash
rails db:create db:migrate db:seed
rails db                          # Database console
```

### Testing & Code Quality
```bash
rails test                        # Run all tests
rails test test/models/foo_test.rb:42  # Single test
bundle exec rubocop -A            # Auto-fix style issues
```

### Rails Console & Generators
```bash
rails console
rails generate model ModelName
```

## Architecture Principles

### 37signals "Vanilla Rails" Philosophy
Following patterns from Basecamp, HEY, and Campfire:

1. **Rich domain models** over service objects
2. **CRUD controllers** over custom actions (everything is a resource)
3. **Concerns** for horizontal code sharing
4. **Records as state** over boolean columns
5. **Database-backed queues and cache** (Solid Stack)
6. **Build it yourself** before reaching for gems
7. **Ship to learn** — prototype quality is valid

### Vladimir Dementyev's Layered Design
From "Layered Design for Ruby on Rails Applications":

1. **Grow into abstractions** — let them emerge from code, don't create empty directories
2. **Service layer as waiting room** — for abstractions not yet revealed
3. **Form Objects** when UI forms diverge from models
4. **Scopes and concerns** for query reuse (not separate Query Objects)

### Abstraction Decision Tree
```
Need new abstraction?
├── Is it a form that differs from model? → Form Object (app/forms/)
├── Is it shared model behavior? → Concern (app/models/concerns/)
├── Is it shared controller behavior? → Concern (app/controllers/concerns/)
├── Is it external service integration? → Client (app/clients/)
├── Is it a complex query? → Scope or concern on the model
└── None of the above? → Keep in model/controller until pattern emerges
```

## Data Model

### Primary Keys
<!-- Choose your ID strategy -->
**Option A: ULIDs** (sortable, distributed-friendly):
```ruby
create_table :accounts, force: true, id: false do |t|
  t.primary_key :id, :string, default: -> { "ULID()" }
  # ...
end
```

**Option B: Standard integer IDs** (Rails default)

### Core Entities
<!-- Define your domain model here -->
```
┌─────────────────────────────────────────────────────────────────┐
│  Entity1                                                        │
│  ├── attribute1, attribute2                                     │
│  └── associations                                               │
│                                                                 │
│  Entity2                                                        │
│  ├── attribute1, attribute2                                     │
│  └── associations                                               │
└─────────────────────────────────────────────────────────────────┘
```

## Testing

### Framework
- **Minitest** (Rails default, per 37signals style)
- **Fixtures** over factories
- **Integration tests** for critical paths

### Fixture Strategy
```yaml
# test/fixtures/[models].yml
example_record:
  name: "Example"
  # ...
```

### Test Helper
```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  # shared setup
end

class ActionDispatch::IntegrationTest
  # integration test setup
end
```

## File Structure

```
app/
├── channels/
├── clients/              # External service wrappers (create when needed)
├── controllers/
│   ├── concerns/
│   └── webhooks/         # Third-party webhooks
├── jobs/
├── mailers/
├── models/
│   └── concerns/
└── views/
    └── layouts/

config/
├── deploy.yml            # Kamal configuration
└── ...
```

**Note:** Create `app/forms/`, `app/clients/` etc. only when needed. Don't create empty directories.

## Authentication System

This template uses **magic link authentication** (passwordless):

### User Authentication
- Users create accounts automatically on first magic link request
- Path: `/session/new`
- Model: `User` (email, name)
- Controller: `SessionsController`
- Mailer: `UserMailer.magic_link`

### Admin Authentication
- Admins must be created by other admins (or via seeds)
- Path: `/admins/session/new`
- Model: `Admin` (email only)
- Controller: `Admins::SessionsController`
- Mailer: `AdminMailer.magic_link`
- Admin panel: `/avo` (requires admin authentication)

### Magic Link Implementation
```ruby
# In models (User/Admin)
def generate_magic_link_token
  signed_id(purpose: :magic_link, expires_in: 15.minutes)
end

# In controllers
user = User.find_signed!(params[:token], purpose: :magic_link)
session[:user_id] = user.id
```

### Helper Methods (ApplicationController)
- `current_user` / `current_admin`
- `authenticate_user!` / `authenticate_admin!`

## Important Development Practices

### Always
- Use `bin/dev` to start the server
- Check logs after every significant change
- Write tests with features (same commit)
- Use magic links for authentication (no passwords)

### Never
- Use Devise (we use magic links)
- Use Sidekiq (Solid Queue instead)
- Create empty directories "for later"
- Add gems before trying vanilla Rails
- Create boolean columns for state (use records or enums)

### Code Style
- RuboCop with auto-fix via lefthook
- `params.expect()` for parameter handling (Rails 8.1+)
- Thin controllers, rich models
- Concerns for shared behavior
- CRUD resources for everything

## Credentials

This project uses Rails encrypted credentials exclusively. No environment variables are used.

```bash
# Edit credentials
rails credentials:edit --environment development
rails credentials:edit --environment production
```

```yaml
# Example structure
secret_key_base: <auto-generated>

# Litestream (optional, configured via bin/configure)
litestream:
  replica_bucket: my-app-backups
  replica_key_id: AKIAIOSFODNN7EXAMPLE
  replica_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Other services
stripe:
  secret_key: sk_test_...
  webhook_secret: whsec_...

openai:
  api_key: sk-...

anthropic:
  api_key: sk-ant-...
```

## Litestream - SQLite Replication

Litestream provides continuous replication of SQLite databases to S3-compatible storage (AWS S3, DigitalOcean Spaces, Backblaze B2, etc.).

### Configuration

**During initial setup:**
Run `bin/configure` and provide S3 credentials when prompted. This will:
- Write Litestream config to Rails encrypted credentials
- Configure `config/initializers/litestream.rb` to read from credentials

**Manual configuration:**
```bash
rails credentials:edit --environment production
```

Add:
```yaml
litestream:
  replica_bucket: your-bucket-name  # Without https:// prefix
  replica_key_id: YOUR_AWS_KEY_ID
  replica_access_key: YOUR_AWS_SECRET_KEY
```

### What Gets Replicated

Litestream replicates all Solid Stack databases (see `config/litestream.yml`):
- `storage/production.sqlite3` (main database)
- `storage/production_cache.sqlite3` (Solid Cache)
- `storage/production_queue.sqlite3` (Solid Queue)
- `storage/production_cable.sqlite3` (Solid Cable)

### Commands

```bash
# Start replication (in production)
rails litestream:replicate

# Restore from backup
rails litestream:restore

# View configuration
cat config/litestream.yml
```

### Production Usage

In production, Litestream typically runs alongside your Rails app. With Kamal 2, you can run it as a sidecar container or separate process.

## Deployment

Kamal 2 deployment:

```yaml
# config/deploy.yml
service: myapp
image: myorg/myapp

servers:
  web:
    - 1.2.3.4

registry:
  username: myorg
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production
    SOLID_QUEUE_IN_PUMA: true
  secret:
    - RAILS_MASTER_KEY
```

---

## Optional Sections

<!-- Include these sections if relevant to your project -->

### Multi-Tenancy Architecture (if applicable)
Following 37signals pattern: subdomain-based tenancy with middleware.

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :account, :user
end
```

### AI Integration Patterns (if applicable)

**Graceful Degradation:**
```ruby
module AiResilient
  extend ActiveSupport::Concern

  def process_with_resilience
    yield
  rescue SomeAIError => e
    handle_gracefully(e)
  end
end
```

**Separating Instructions from Data:**
```ruby
def messages_for_ai
  [
    { role: :system, content: system_prompt },      # Pure instructions
    *messages.map { |m| { role: m.role, content: m.content } }
  ]
end
# User content is ALWAYS in user/assistant messages, never injected into system
```
