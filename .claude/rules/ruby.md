---
description: Ruby/Rails code conventions
globs: ["**/*.rb"]
---

# Ruby Code Standards

## Style

- Use Ruby 3.x syntax features (pattern matching, endless methods where appropriate)
- Prefer `&&` and `||` over `and` and `or`
- Use trailing commas in multi-line arrays/hashes
- Maximum line length: 120 characters
- Use double quotes for strings unless interpolation is needed

## Rails Conventions

- **Fat models, thin controllers** - Business logic belongs in models
- **Use concerns** for shared behavior (named as adjectives: Closeable, Watchable)
- **Prefer scopes** over class methods for queries
- **Use `Current` attributes** for request-local state (Current.user, Current.session)
- **Database constraints over validations** where possible

## Naming

```ruby
# Methods that return boolean
def closed? = closure.present?
def can_edit? = author == Current.user

# Action methods (verbs)
def close = create_closure!
def publish = update!(published_at: Time.current)

# Scopes (adverbs/descriptors)
scope :chronologically, -> { order(created_at: :asc) }
scope :preloaded, -> { includes(:author, :comments) }
```

## Avoid

- Service objects (use model methods or concerns)
- Query objects (use scopes on models)
- Callbacks for business logic (explicit method calls preferred)
- `before_action` chains that are hard to follow
- N+1 queries (use `includes` in controllers)
- `.count` on associations when counter cache exists (use `_count` column)
- `.find_by`/`.order.first` on preloaded associations (use Ruby `.find { }`/`.min_by`)
- Multiple passes over the same collection (use `partition`/`group_by`)
- Looped `create`/`perform_later` (use `insert_all`/`perform_all_later`)
- Empty directories created "for later"
- **`OpenStruct`** - never use it (slow, no typo protection, memory bloat). Use `Struct`, `Data`, plain hashes, or dedicated classes instead

## Testing

- Use Minitest, not RSpec
- Use fixtures, not factories
- Test behavior, not implementation
- One assertion per test when reasonable