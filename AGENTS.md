# Template - Rails 8 AI-Native Application

## Tech Stack

- **Ruby**: 4.0.x
- **Rails**: 8.x
- **Database**: SQLite with Solid Stack (Cache, Queue, Cable)
- **Replication**: Litestream (SQLite → S3-compatible storage)
- **AI**: RubyLLM (OpenAI & Anthropic support)
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS 4
- **Asset Pipeline**: Propshaft
- **Deployment**: Kamal 2
- **Admin Panel**: Madmin
- **Icons**: inline_svg gem
- **Primary Keys**: ULIDs (database-level default)

## Quick Reference

```bash
# Development
bin/dev                    # Start server (Puma + Tailwind watcher)
bin/setup                  # Install deps, setup DB
bin/ci                     # Run full CI locally

# Database
rails db:migrate           # Run migrations
rails db:seed              # Seed data
rails db                   # SQLite console

# Testing
rails test                 # All tests
rails test test/models/    # Model tests only
rails test test/models/user_test.rb:42  # Specific line

# Code quality
bundle exec rubocop -A     # Lint + autofix
bundle exec brakeman       # Security scan

# Deployment
kamal deploy               # Deploy to production
kamal app logs             # View production logs
```

## Architecture Principles

This template follows **37signals vanilla Rails philosophy** combined with **Vladimir Dementyev's Layered Design**:

### Core Philosophy

> "The best code is the code you don't write. The second best is the code that's obviously correct."

1. **Rich domain models over service objects** - Put business logic in models
2. **CRUD controllers over custom actions** - Everything is a resource
3. **Concerns for horizontal code sharing** - Named as adjectives (Closeable, Publishable)
4. **Records as state instead of boolean columns** - `card.closure` instead of `card.closed`
5. **Database-backed everything** - SQLite + Solid Stack (no Redis)
6. **Build solutions before reaching for gems**
7. **Grow into abstractions** - Let them emerge from code, don't create empty directories
8. **Ship to learn** - Prototype quality is valid

### Abstraction Decision Tree

```
Need new abstraction?
├── Is it shared model behavior? → Concern (app/models/concerns/)
├── Is it shared controller behavior? → Concern (app/controllers/concerns/)
├── Is it a complex query? → Scope or concern on the model
└── None of the above? → Keep in model/controller until pattern emerges
```

**Principle:** Don't create directories in anticipation. Let abstractions emerge from code.

### What We Deliberately Avoid

- ❌ devise (custom ~150-line auth)
- ❌ pundit/cancancan (simple role checks in models)
- ❌ sidekiq (Solid Queue uses database)
- ❌ redis (database for everything)
- ❌ view_component (partials work fine)
- ❌ GraphQL (REST with Turbo sufficient)
- ❌ React/Vue/npm/yarn (Hotwire + Stimulus only)

### REST Mapping

Instead of custom controller actions, create new resources:

```ruby
# ❌ BAD: Custom actions
POST /cards/:id/close
DELETE /cards/:id/close

# ✅ GOOD: Resource-based
POST /cards/:id/closure      # Cards::ClosuresController#create
DELETE /cards/:id/closure    # Cards::ClosuresController#destroy
```

## Code Conventions

### Naming

| Type | Convention | Example |
|------|------------|---------|
| Verbs | Action methods | `card.close`, `card.gild`, `board.publish` |
| Predicates | Boolean queries | `card.closed?`, `card.golden?` |
| Concerns | Adjectives | `Closeable`, `Publishable`, `Watchable` |
| Controllers | Nouns matching resources | `Cards::ClosuresController` |
| Scopes | Descriptive | `chronologically`, `preloaded`, `sorted_by` |

### Controllers

```ruby
# Thin controllers - delegate to models
class Cards::ClosuresController < ApplicationController
  def create
    @card = Current.user.cards.find(params[:card_id])
    @card.close
    redirect_to @card
  end
end
```

### Models

```ruby
# Fat models with concerns
class Card < ApplicationRecord
  include Closeable
  include Watchable

  belongs_to :board
  has_one :closure, dependent: :destroy

  scope :open, -> { where.missing(:closure) }
  scope :chronologically, -> { order(created_at: :asc) }
  scope :preloaded, -> { includes(:closure, :board) }
end
```

### Concerns

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

  def closed?
    closure.present?
  end
end
```

### Views & Frontend

- **Turbo Frames** for partial page updates
- **Turbo Streams** for real-time updates
- **Stimulus** for JavaScript sprinkles
- **No JavaScript frameworks** - vanilla Stimulus only
- **inline_svg gem** for all icons (never inline SVG in ERB)

```erb
<%# Turbo Frame for inline editing %>
<%= turbo_frame_tag dom_id(@card) do %>
  <%= render @card %>
<% end %>

<%# Stimulus controller %>
<div data-controller="dropdown">
  <button data-action="click->dropdown#toggle">Menu</button>
  <div data-dropdown-target="menu" class="hidden">...</div>
</div>

<%# Icons - ALWAYS use inline_svg, never inline SVG code %>
<%= inline_svg "icons/users.svg", class: "w-6 h-6 text-blue-600" %>
```

### Stimulus Controllers

```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }
}
```

## Database

### SQLite + Solid Stack

- **Main DB**: `storage/development.sqlite3`
- **Cache**: `storage/development_cache.sqlite3` (Solid Cache)
- **Queue**: `storage/development_queue.sqlite3` (Solid Queue)
- **Cable**: `storage/development_cable.sqlite3` (Solid Cable)

### Migrations

```ruby
class CreateCards < ActiveRecord::Migration[8.0]
  def change
    create_table :cards, id: false, force: true do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
      t.references :board, null: false, foreign_key: true, type: :string
      t.string :title, null: false
      t.text :description

      t.timestamps
    end

    add_index :cards, [:board_id, :created_at]
  end
end
```

### ULID Primary Keys

All models use ULID primary keys generated at the database level:

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  self.implicit_order_column = "created_at"
  # No callback needed - SQLite generates ULIDs via ULID() function
end
```

## Authentication

### Magic Link Flow (Passwordless)

**User Authentication:**
1. User enters email at `/session/new`
2. System generates signed token, sends email
3. User clicks link, token verified, session created
4. First-time users: account created automatically
5. After login: redirects to `/home`

**Admin Authentication:**
- Path: `/admins/session/new` (separate from user login)
- Admins must exist in database (created via seeds or Madmin)
- After login: redirects to `/madmin`
- **No links between user and admin interfaces**

```ruby
# app/models/user.rb
class User < ApplicationRecord
  def generate_magic_link_token
    signed_id(purpose: :magic_link, expires_in: 15.minutes)
  end
end

# In controllers
user = User.find_signed!(params[:token], purpose: :magic_link)
session[:user_id] = user.id
```

### Helper Methods (ApplicationController)

- `current_user` - for public user interface
- `current_admin` - for Madmin admin interface
- `authenticate_user!` - for user-facing controllers
- `authenticate_admin!` - for admin-specific controllers

## Madmin Admin Panel

All administrative tasks are managed through **Madmin** at `/madmin`.

### Configuration

```ruby
# app/controllers/madmin/application_controller.rb
class Madmin::ApplicationController < Madmin::BaseController
  before_action :authenticate_admin!

  private

  def authenticate_admin!
    redirect_to main_app.new_admins_session_path unless current_admin
  end

  def current_admin
    @current_admin ||= Admin.find_by(id: session[:admin_id]) if session[:admin_id]
  end
  helper_method :current_admin
end
```

### Creating Resources

```bash
rails generate madmin:resource ModelName
```

Customize in `app/madmin/resources/model_name_resource.rb`.

## Testing

### Minitest + Fixtures

```ruby
# test/models/card_test.rb
class CardTest < ActiveSupport::TestCase
  test "can be closed" do
    card = cards(:one)
    assert_not card.closed?

    card.close
    assert card.closed?
  end
end
```

### System Tests

```ruby
# test/system/cards_test.rb
class CardsTest < ApplicationSystemTestCase
  test "creating a card" do
    visit board_path(boards(:one))
    click_on "New Card"
    fill_in "Title", with: "Test Card"
    click_on "Create"
    assert_text "Test Card"
  end
end
```

## File Structure

```
app/
├── channels/
├── controllers/
│   ├── application_controller.rb
│   ├── concerns/
│   ├── sessions_controller.rb
│   ├── admins/           # Admin authentication
│   │   └── sessions_controller.rb
│   └── madmin/           # Madmin resource controllers
├── jobs/
├── mailers/
├── madmin/
│   ├── fields/           # Custom Madmin fields
│   └── resources/        # Madmin resource definitions
├── models/
│   ├── application_record.rb
│   ├── concerns/
│   └── current.rb        # Current attributes
└── views/
    ├── layouts/
    ├── madmin/           # Customized Madmin views
    └── shared/

app/javascript/
└── controllers/          # Stimulus controllers only

app/assets/
├── images/
│   └── icons/            # SVG icons for inline_svg
└── stylesheets/
    └── application.css   # Tailwind
```

## Credentials

All secrets in Rails encrypted credentials (no environment variables):

```bash
rails credentials:edit --environment development
rails credentials:edit --environment production
```

Structure:
```yaml
secret_key_base: ...

# AI APIs (configured via bin/configure)
open_ai:
  api_key: sk-...

anthropic:
  api_key: sk-ant-...

# Litestream SQLite replication (optional)
litestream:
  replica_bucket: my-app-backups
  replica_key_id: AKIAIOSFODNN7EXAMPLE
  replica_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Other services
stripe:
  secret_key: sk_test_...
  webhook_secret: whsec_...
```

### Litestream - SQLite Replication

Replicates all Solid Stack databases to S3-compatible storage:
- `storage/production.sqlite3` (main database)
- `storage/production_cache.sqlite3` (Solid Cache)
- `storage/production_queue.sqlite3` (Solid Queue)
- `storage/production_cable.sqlite3` (Solid Cable)

```bash
rails litestream:replicate  # Start replication
rails litestream:restore    # Restore from backup
```

## Quality Gates

Before committing, ensure:

```bash
bundle exec rubocop -A      # ✅ No lint errors
rails test                   # ✅ All tests pass
bundle exec brakeman -q      # ✅ No security issues
```

## AI Collaboration Notes

When working with AI assistants:

1. **Read AGENTS.md files** in directories you're modifying
2. **Update AGENTS.md** with patterns you discover
3. **Follow existing conventions** - don't introduce new patterns without discussion
4. **Keep controllers thin** - business logic goes in models
5. **Use concerns** for shared behavior across models
6. **Prefer database constraints** over model validations where possible
7. **Write tests** for new functionality
8. **Run quality gates** before marking work complete

## Deployment

Kamal 2 deployment:

```bash
kamal setup    # First-time setup
kamal deploy   # Deploy
kamal app logs # View logs
```

```yaml
# config/deploy.yml
service: myapp
image: myorg/myapp

servers:
  web:
    - 1.2.3.4

env:
  clear:
    RAILS_ENV: production
    SOLID_QUEUE_IN_PUMA: true
  secret:
    - RAILS_MASTER_KEY
```

---

## Optional: RubyLLM AI Chat Integration

If your project includes AI chat functionality:

### Data Model

```
User
└── has_many :chats

Chat
├── belongs_to :user
├── belongs_to :model (AI model)
├── acts_as_chat (RubyLLM)
└── has_many :messages

Message
├── belongs_to :chat
├── role (system/user/assistant)
├── content, content_raw
└── token counts
```

### Configuration

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.dig(:open_ai, :api_key)
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic, :api_key)
end
```

### Usage

```ruby
class Chat < ApplicationRecord
  belongs_to :user
  acts_as_chat  # RubyLLM integration
end
```

Chat responses processed via `ChatResponseJob` using Solid Queue.
