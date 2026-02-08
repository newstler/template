---
name: review-code
description: Review code changes against Rails conventions and 37signals style
---

# Code Review

Review the current changes against Rails conventions and 37signals style.

## 1. See What Changed

```bash
git status
git diff
git diff --cached  # If already staged
```

## 2. Review Checklist

### Controllers

- [ ] Maps to CRUD actions only (no custom actions)
- [ ] Uses nested resources for state changes (`/cards/:id/closure`)
- [ ] Thin - delegates business logic to models
- [ ] Uses `Current` for request context
- [ ] Proper `before_action` for authentication/authorization
- [ ] Strong parameters in private method

### Models

- [ ] Uses concerns for shared behavior (named as adjectives)
- [ ] State tracked via records, not boolean columns
- [ ] Scopes for common queries (`preloaded`, `chronologically`)
- [ ] Validations backed by database constraints
- [ ] No service objects (use model methods)
- [ ] Callbacks used sparingly

### Views

- [ ] Uses Turbo Frames for partial updates
- [ ] Uses Turbo Streams for multi-element updates
- [ ] Stimulus for JS behavior (no React/Vue)
- [ ] Partials for reusable components
- [ ] No complex logic in templates
- [ ] Uses helpers for formatting

### Tests

- [ ] Uses Minitest (not RSpec)
- [ ] Uses fixtures (not FactoryBot)
- [ ] Tests behavior, not implementation
- [ ] Covers happy path and edge cases
- [ ] System tests for critical flows

### Database

- [ ] Uses UUIDv7 primary keys (`id: { type: :string, default: -> { "uuid7()" } }`)
- [ ] Foreign keys with proper type: :string
- [ ] Indexes on foreign keys and common queries
- [ ] Null constraints where appropriate
- [ ] State as separate tables, not booleans

## 3. Run Quality Gates

```bash
bundle exec rubocop -A
rails test
bin/brakeman --no-pager
```

## 4. Common Issues

### Anti-pattern: Service Object

```ruby
# ❌ BAD
class CardCloser
  def call(card, user)
    card.update!(closed: true, closed_by: user)
  end
end

# ✅ GOOD
class Card < ApplicationRecord
  def close(by: Current.user)
    create_closure!(closed_by: by)
  end
end
```

### Anti-pattern: Custom Controller Action

```ruby
# ❌ BAD
class CardsController
  def close
    @card.update!(closed: true)
  end
end

# ✅ GOOD
class Cards::ClosuresController
  def create
    @card.close
  end
end
```

### Anti-pattern: Boolean State Column

```ruby
# ❌ BAD
add_column :cards, :closed, :boolean, default: false

# ✅ GOOD
create_table :closures do |t|
  t.references :card, null: false
  t.timestamps
end
```

## 5. Report Format

Summarize findings:

```markdown
## Summary
What was reviewed

## ✅ What's Good
- Follows REST conventions
- Tests cover main scenarios

## ⚠️ Suggestions
- Consider extracting X to a concern
- Add index on frequently queried column

## ❌ Issues
- Service object should be model method
- Missing tests for edge case
```