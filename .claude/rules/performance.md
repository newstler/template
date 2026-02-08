# Performance Standards

## Philosophy

**Every query counts.** Avoid N+1 queries, unnecessary object instantiation, and redundant iterations. Think about what SQL will be generated before writing ActiveRecord code.

## Eager Loading

Always use `includes` when accessing associations in loops:

```ruby
# ❌ BAD: N+1 queries (1 query for chats + N queries for messages)
@chats = current_user.chats
@chats.each { |chat| chat.messages.first }

# ✅ GOOD: 2 queries total
@chats = current_user.chats.includes(:messages)
@chats.each { |chat| chat.messages.first }
```

When rendering views that access associations, add `includes` in the controller:

```ruby
# Controller
def index
  @chats = current_user.chats.includes(:model, :messages).recent
end

def show
  @chat = current_user.chats.includes(messages: [:attachments, :tool_calls]).find(params[:id])
end
```

## Counter Caches Over .count

When a counter cache column exists, use it instead of `.count`:

```erb
<%# ❌ BAD: Triggers COUNT query %>
<%= chat.messages.count %>

<%# ✅ GOOD: Reads cached column (zero queries) %>
<%= chat.messages_count %>
```

Also use counter cache for existence checks:

```erb
<%# ❌ BAD: Triggers query %>
<% if chat.messages.any? %>

<%# ✅ GOOD: Reads cached column %>
<% if chat.messages_count > 0 %>
```

## Collection Rendering

Use collection rendering instead of loops with `render`:

```erb
<%# ❌ BAD: N partial lookups + N instrumentations %>
<% @messages.each do |message| %>
  <%= render message %>
<% end %>

<%# ✅ GOOD: 1 partial lookup + 1 instrumentation (~2x faster) %>
<%= render partial: "messages/message", collection: @messages, as: :message %>

<%# ✅ GOOD: With caching (~1.7x faster on cache hits) %>
<%= render partial: "messages/message", collection: @messages, as: :message, cached: true %>
```

## Ruby Methods on Preloaded Collections

When associations are eager loaded, use Ruby methods instead of ActiveRecord queries to avoid extra SQL:

```ruby
# ❌ BAD: Triggers SQL even though messages are preloaded
chat.messages.order(:created_at).first
chat.messages.find_by(role: "user")
chat.messages.sum(:input_tokens)

# ✅ GOOD: Uses Ruby on the already-loaded array
chat.messages.min_by(&:created_at)
chat.messages.find { |m| m.role == "user" }
chat.messages.sum(&:input_tokens)
```

## Single-Pass Iteration

Don't iterate the same collection multiple times:

```ruby
# ❌ BAD: Two passes over the same array
@monthly = @prices.select { |p| p.interval == "month" }
@yearly = @prices.select { |p| p.interval == "year" }

# ✅ GOOD: Single pass with partition
@monthly, @yearly = @prices.partition { |p| p.interval == "month" }

# ✅ GOOD: Single pass with group_by (for 3+ groups)
grouped = @prices.group_by(&:interval)
```

## Bulk Operations

### Bulk Record Creation

```ruby
# ❌ BAD: N inserts with N transactions
items.each { |attrs| Item.create(attrs) }

# ✅ GOOD: 1 insert (skips validations/callbacks)
Item.insert_all(items_attributes)
```

### Bulk Job Enqueuing

```ruby
# ❌ BAD: N enqueue operations
items.each { |item| ProcessItemJob.perform_later(item.id) }

# ✅ GOOD: 1 bulk enqueue (~3.5x faster)
jobs = items.map { |item| ProcessItemJob.new(item.id) }
ActiveJob.perform_all_later(jobs)
```

## Lazy Loading Below the Fold

Use Turbo Frames for content unlikely to be viewed immediately:

```erb
<%# ❌ BAD: Renders immediately even if user never scrolls down %>
<%= render "comments", comments: @comments %>

<%# ✅ GOOD: Loads only when visible (zero cost if never seen) %>
<%= turbo_frame_tag "comments", src: article_comments_path(@article), loading: :lazy do %>
  <p>Loading comments...</p>
<% end %>
```

## Associations Over Methods

Prefer associations over methods that return query results:

```ruby
# ❌ BAD: Triggers SQL on every call, no caching
def active_subscription
  subscriptions.where(active: true).first
end

# ✅ GOOD: Cached after first load, works with includes
has_one :active_subscription, -> { where(active: true) }, class_name: "Subscription"
```

## Small Partials

For very small, frequently-rendered partials (just a tag or two), consider using helpers instead:

```ruby
# ❌ BAD: Partial with expensive lookup for simple markup
# _avatar.html.erb: <img src="<%= url %>" alt="<%= name %>'s avatar">

# ✅ GOOD: Helper (~2x faster than partial)
def avatar_tag(url, name)
  tag.img(src: url, alt: "#{name}'s avatar")
end
```

Only optimize this way for truly small, high-frequency partials. Normal-sized partials are fine.
