---
name: dhh-rails-style
description: Write Ruby and Rails code in DHH's 37signals style. Use when writing Rails code, creating models, controllers, or any Ruby file. Embodies REST purity, fat models, thin controllers, Current attributes, Hotwire patterns, and "clarity over cleverness."
trigger: ruby, rails, model, controller, concern, hotwire, turbo, stimulus
---

# DHH Rails Style Guide

Apply 37signals/DHH conventions to Ruby and Rails code.

## Core Philosophy

> "The best code is the code you don't write. The second best is the code that's obviously correct."

**Vanilla Rails is plenty:**
- Rich domain models over service objects
- CRUD controllers over custom actions
- Concerns for horizontal code sharing
- Records as state instead of boolean columns
- Database-backed everything (no Redis)
- Build solutions before reaching for gems

## What We Deliberately Avoid

| Avoid | Use Instead |
|-------|-------------|
| devise | Custom ~150-line auth |
| pundit/cancancan | Simple role checks in models |
| sidekiq | Solid Queue (database-backed) |
| redis | Database for everything |
| view_component | Partials |
| GraphQL | REST with Turbo |
| React/Vue | Hotwire + Stimulus |
| RSpec | Minitest |
| FactoryBot | Fixtures |

## Naming Conventions

### Methods

```ruby
# Verbs for actions
card.close
card.gild
board.publish

# Predicates return boolean
card.closed?
card.golden?
user.admin?

# Avoid set_ methods
# ❌ card.set_status("closed")
# ✅ card.close
```

### Concerns

Name as adjectives describing capability:

```ruby
module Closeable
  extend ActiveSupport::Concern
  # ...
end

module Publishable; end
module Watchable; end
module Searchable; end
```

### Scopes

```ruby
# Ordering
scope :chronologically, -> { order(created_at: :asc) }
scope :reverse_chronologically, -> { order(created_at: :desc) }
scope :alphabetically, -> { order(name: :asc) }
scope :latest, -> { order(created_at: :desc).limit(1) }

# Eager loading
scope :preloaded, -> { includes(:author, :comments) }

# Parameterized
scope :sorted_by, ->(column) { order(column) }
scope :created_after, ->(date) { where("created_at > ?", date) }
```

### Controllers

Nouns matching resources:

```ruby
# ❌ Bad: Custom actions
class CardsController
  def close; end
  def reopen; end
end

# ✅ Good: Nested resource
class Cards::ClosuresController
  def create; end   # POST /cards/:id/closure
  def destroy; end  # DELETE /cards/:id/closure
end
```

## REST Mapping

Transform custom actions into resources:

```
POST /cards/:id/close    → POST /cards/:id/closure
DELETE /cards/:id/close  → DELETE /cards/:id/closure
POST /cards/:id/archive  → POST /cards/:id/archival
POST /cards/:id/publish  → POST /cards/:id/publication
```

## Controller Patterns

```ruby
class Cards::ClosuresController < ApplicationController
  before_action :set_card

  def create
    @card.close(by: Current.user)
    redirect_to @card
  end

  def destroy
    @card.reopen(by: Current.user)
    redirect_to @card
  end

  private

  def set_card
    @card = Current.user.cards.find(params[:card_id])
  end
end
```

## Model Patterns

### State as Records

```ruby
# ❌ Bad: Boolean column
class Card < ApplicationRecord
  # closed: boolean
  def close
    update!(closed: true)
  end
end

# ✅ Good: State record
class Card < ApplicationRecord
  has_one :closure, dependent: :destroy

  def close(by: Current.user)
    create_closure!(closed_by: by)
  end

  def closed?
    closure.present?
  end
end

class Closure < ApplicationRecord
  belongs_to :card
  belongs_to :closed_by, class_name: "User"
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

  def reopen
    closure&.destroy
  end

  def closed?
    closure.present?
  end
end
```

## Current Attributes

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :session, :request_id

  def user=(user)
    super
    Time.zone = user&.time_zone || "UTC"
  end
end

# Usage anywhere
Current.user
Current.session
```

## Frontend Patterns

### Turbo Frames

```erb
<%= turbo_frame_tag dom_id(@card) do %>
  <%= render @card %>
<% end %>
```

### Turbo Streams

```erb
<%# app/views/cards/create.turbo_stream.erb %>
<%= turbo_stream.prepend "cards", @card %>
<%= turbo_stream.update "flash", partial: "shared/flash" %>
```

### Stimulus

```javascript
// Small, focused controllers
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }
}
```

## Testing

```ruby
# Minitest + fixtures
class CardTest < ActiveSupport::TestCase
  test "can be closed" do
    card = cards(:open)
    card.close(by: users(:admin))
    assert card.closed?
  end
end
```

## Success Criteria

Code follows DHH style when:

- [ ] Controllers map to CRUD verbs on resources
- [ ] Models use concerns for horizontal behavior
- [ ] State tracked via records, not booleans
- [ ] No service objects or unnecessary abstractions
- [ ] Database-backed solutions (no Redis)
- [ ] Tests use Minitest with fixtures
- [ ] Turbo/Stimulus for interactivity
- [ ] No npm/yarn dependencies
