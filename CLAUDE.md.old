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
   - Optionally configure OpenAI and Anthropic (Claude) API keys
   - Optionally configure Litestream for SQLite replication
   - Run `bin/setup` to install dependencies and setup database

### Tech Stack

- **Ruby**: 4.0.x
- **Rails**: 8.x
- **Database**: SQLite with Solid Stack
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **Replication**: Litestream (SQLite → S3-compatible storage)
- **AI**: RubyLLM (OpenAI & Anthropic support)
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
│   ├── madmin/           # Madmin resource controllers
│   └── webhooks/         # Third-party webhooks
├── jobs/
├── mailers/
├── madmin/
│   ├── fields/           # Custom Madmin fields (Json, Gravatar)
│   └── resources/        # Madmin resource definitions
├── models/
│   └── concerns/
└── views/
    ├── layouts/
    └── madmin/           # Customized Madmin views (generated as needed)

config/
├── deploy.yml            # Kamal configuration
└── ...
```

**Note:** Create `app/forms/`, `app/clients/` etc. only when needed. Don't create empty directories.

## Authentication System

This template uses **magic link authentication** (passwordless) with complete separation of user and admin interfaces:

### User Authentication (Public Interface)
- Users create accounts automatically on first magic link request
- Path: `/session/new`
- Model: `User` (email, name)
- Controller: `SessionsController`
- Mailer: `UserMailer.magic_link`
- After login: redirects to `/home`

### Admin Authentication (Madmin Interface)
- **All admin management happens through Madmin at `/madmin`**
- Path: `/admins/session/new` (admin login form)
- Model: `Admin` (email only)
- Controller: `Admins::SessionsController`
- Mailer: `AdminMailer.magic_link`
- After magic link click: redirects to `/madmin`
- Admins must exist in database (created via seeds or Madmin)

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
- `current_user` - for public user interface
- `current_admin` - for Madmin admin interface
- `authenticate_user!` - for user-facing controllers
- `authenticate_admin!` - for admin-specific controllers (not Madmin)

### Interface Separation
**IMPORTANT:** Keep interfaces completely separate:
- User interface: `/session/new`, `/home`, `/chats`, etc.
- Admin interface: `/admins/session/new` (login), `/madmin` (admin panel)
- **No links between user and admin interfaces**
- Admin login is separate from user login (different URLs, different styling)
- All admin CRUD operations happen through Madmin resources

## Madmin Admin Panel

All administrative tasks are managed through **Madmin** at `/madmin`. Admin authentication uses `Admins::SessionsController`, and all CRUD operations are performed through Madmin's generated controllers and views.

### Available Resources
- **Admins** - Manage admin users, send magic links
- **Users** - View/edit users, filter by created date, see their chats
- **Chats** - View all AI chat sessions, filter by created date
- **Messages** - Inspect individual messages, tokens, tool calls; filter by role and created date
- **Models** - View available AI models, refresh from RubyLLM, filter by provider
- **Tool Calls** - Debug function/tool calls, filter by created date

### Admin Actions
- **Send Magic Link** (Admin detail page) - Send login link to specific admin
- **Refresh Models** (Models index) - Update AI model registry from RubyLLM

### Madmin Configuration

```ruby
# app/controllers/madmin/application_controller.rb
class Madmin::ApplicationController < Madmin::BaseController
  before_action :authenticate_admin!

  private

  def authenticate_admin!
    admin = Admin.find_by(id: session[:admin_id]) if session[:admin_id]
    redirect_to main_app.new_admins_session_path unless admin
  end

  helper_method :current_admin

  def current_admin
    @current_admin ||= Admin.find_by(id: session[:admin_id]) if session[:admin_id]
  end
end
```

### Creating Madmin Resources

```ruby
class ModelResource < Madmin::Resource
  attribute :id, form: false
  attribute :name
  attribute :email
  attribute :association  # belongs_to or has_many
  attribute :json_field, field: JsonField
  attribute :email_with_gravatar, field: GravatarField, form: false
  attribute :created_at, form: false

  def self.searchable_attributes
    [:name, :email]
  end
end
```

**Controllers:** `app/controllers/madmin/[models]_controller.rb`
**Resources:** `app/madmin/resources/[model]_resource.rb`
**Custom Fields:** `app/madmin/fields/[field]_field.rb`
**Views:** `app/views/madmin/[models]/` (generated as needed)

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
- Create separate admin controllers/views outside Madmin (use Madmin resources/controllers)
- Mix user and admin interfaces (keep completely separate)
- Link to admin interface from user interface
- Write inline SVG in ERB files (use inline_svg gem with .svg files)

### Code Style
- RuboCop with auto-fix via lefthook
- `params.expect()` for parameter handling (Rails 8.1+)
- Thin controllers, rich models
- Concerns for shared behavior
- CRUD resources for everything

### Dark Mode & Styling

This template uses a **dark theme** with centralized CSS utility classes for consistent styling.

**DRY Background Utilities:**
```css
/* In app/assets/stylesheets/application.css */

.body-bg {
  @apply bg-dark-950 text-dark-100 min-h-screen;
}

.card-bg {
  @apply bg-dark-900/50 rounded-xl shadow-lg shadow-black/20;
}
```

**Usage:**
```erb
<%# Layouts - use body-bg on <body> %>
<body class="body-bg">

<%# Cards and containers - use card-bg %>
<div class="card-bg p-6">
  <!-- card content -->
</div>
```

**Color Palette** (defined in Tailwind config):
- `dark-50` to `dark-950`: Gray scale from light to dark
- `dark-950`: Darkest background (body)
- `dark-900/50`: Semi-transparent card backgrounds
- `dark-700`: Borders and dividers

**Key Files:**
- `app/assets/stylesheets/application.css` - CSS variables and utility classes
- `config/tailwind.config.js` - Tailwind color palette

**Benefits:**
- Change background colors site-wide by editing ONE line in CSS
- Consistent styling across all views
- Easier theme adjustments

### Icons and SVG
**STRICT RULE:** Never write inline SVG code directly in ERB files.

Always use the `inline_svg` gem with separate `.svg` files:

```ruby
# Good ✓
<%= inline_svg "icons/users.svg", class: "w-6 h-6 text-blue-600" %>

# Bad ✗
<svg class="w-6 h-6">
  <path d="..." />
</svg>
```

**Icon organization:**
- Store icons in `app/assets/images/icons/` (Rails asset pipeline convention)
- Use semantic names: `users.svg`, `chat.svg`, `settings.svg`
- Keep SVG files clean and minimal (viewBox, paths only)
- Icons inherit color via `currentColor` and `stroke="currentColor"`

**Benefits:**
- Easy to update icons across the app
- Icons can be reused everywhere
- Cleaner ERB templates
- Better maintainability

## Credentials

This project uses **environment-specific** Rails encrypted credentials. No environment variables are used.

### Configuration
Credentials are automatically configured when running `bin/configure`:
- Development: `config/credentials/development.yml.enc`
- Development key: `config/credentials/development.key` (gitignored)
- Production: `config/credentials/production.yml.enc`
- Production key: `config/credentials/production.key` (gitignored)

### Editing Credentials
```bash
# Edit development credentials
rails credentials:edit --environment development

# Edit production credentials
rails credentials:edit --environment production
```

### Structure
```yaml
# AI APIs (configured via bin/configure)
open_ai:
  api_key: sk-...

anthropic:
  api_key: sk-ant-...

# Litestream (optional, configured via bin/configure)
litestream:
  replica_bucket: my-app-backups
  replica_key_id: AKIAIOSFODNN7EXAMPLE
  replica_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Other services
stripe:
  secret_key: sk_test_...
  webhook_secret: whsec_...
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

### RubyLLM - AI Chat Integration

This template includes **RubyLLM** for AI chat functionality with OpenAI and Anthropic (Claude) APIs.

**Data Model:**
```
┌─────────────────────────────────────────────────────────────────┐
│  User                                                           │
│  └── has_many :chats                                            │
│                                                                 │
│  Chat                                                           │
│  ├── belongs_to :user                                           │
│  ├── belongs_to :model (AI model)                              │
│  └── has_many :messages                                         │
│                                                                 │
│  Message                                                        │
│  ├── belongs_to :chat                                           │
│  ├── role (system/user/assistant)                              │
│  ├── content (text)                                             │
│  ├── content_raw (JSON with full API response)                 │
│  └── token counts (input/output/cached)                        │
│                                                                 │
│  Model (AI model registry)                                     │
│  ├── model_id (e.g., "gpt-4", "claude-3-5-sonnet")            │
│  ├── provider (openai/anthropic)                               │
│  └── capabilities, pricing, metadata                           │
└─────────────────────────────────────────────────────────────────┘
```

**Controllers & Routes:**
- `/chats` - ChatsController (index, new, create, show)
- `/chats/:chat_id/messages` - MessagesController (create)
- `/models` - ModelsController (index, show, refresh)

All RubyLLM controllers require user authentication (`before_action :authenticate_user!`).

**Background Processing:**
Chat responses are processed asynchronously via `ChatResponseJob` using Solid Queue.

**Configuration:**
```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.dig(:open_ai, :api_key)
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic, :api_key)
  config.default_model = "gpt-4.1-nano"
  config.use_new_acts_as = true  # Use association-based API
end
```

**Usage in Models:**
```ruby
class Chat < ApplicationRecord
  belongs_to :user
  acts_as_chat messages_foreign_key: :chat_id  # RubyLLM integration
end
```

**Best Practices:**
1. **User scoping** - Always scope chats to `current_user`
2. **Async processing** - Use background jobs for AI responses
3. **Token tracking** - Monitor token usage via Message model
4. **Model management** - Use `/models/refresh` to update available models
