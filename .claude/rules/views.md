---
description: ERB and view conventions
globs: ["app/views/**/*.erb", "app/views/**/*.html.erb"]
---

# View Standards

## Philosophy

- **Server-rendered HTML first** - Turbo for interactivity
- **Partials for reuse** - Extract shared components
- **Helpers for complex logic** - Keep templates clean
- **No JavaScript frameworks** - Stimulus only when needed

## ERB Conventions

```erb
<%# Good: Clean, readable templates %>
<article class="card">
  <h2><%= @card.title %></h2>
<%= render @card.description %>
</article>

<%# Bad: Logic in templates %>
<% if @card.author == Current.user && @card.published? && !@card.archived? %>
...
<% end %>

<%# Good: Extract to model method %>
<% if @card.editable_by?(Current.user) %>
...
<% end %>
```

## Turbo Frames

```erb
<%# Wrap content that updates independently %>
<%= turbo_frame_tag dom_id(@card) do %>
<%= render @card %>
<% end %>

<%# Lazy loading %>
<%= turbo_frame_tag "comments", src: card_comments_path(@card), loading: :lazy do %>
  <p>Loading comments...</p>
<% end %>
```

## Turbo Streams

```erb
<%# app/views/cards/create.turbo_stream.erb %>
<%= turbo_stream.prepend "cards", @card %>
<%= turbo_stream.update "card_count", Card.count %>

<%# Remove element %>
<%= turbo_stream.remove dom_id(@card) %>
```

## Partials

```erb
<%# Naming: _card.html.erb for Card model %>
<%= render @card %>
<%= render @cards %>

<%# With locals %>
<%= render "card", card: @card, show_actions: true %>

<%# Collection with spacer %>
<%= render partial: "card", collection: @cards, spacer_template: "card_spacer" %>
```

### Collection Rendering (REQUIRED)

**Always use collection rendering instead of `.each` with `render`:**

```erb
<%# ❌ BAD: N partial lookups + N instrumentations %>
<% @messages.each do |message| %>
  <%= render message %>
<% end %>

<%# ✅ GOOD: 1 lookup + 1 instrumentation (~2x faster) %>
<%= render partial: "messages/message", collection: @messages, as: :message %>
```

### Counter Caches in Views

When a counter cache column exists, use it instead of `.count`:

```erb
<%# ❌ BAD: Triggers COUNT query %>
<%= chat.messages.count %>

<%# ✅ GOOD: Reads cached column %>
<%= chat.messages_count %>
```

## Forms

```erb
<%# Use form_with (not form_for) %>
<%= form_with model: @card do |f| %>
<%= f.label :title %>
<%= f.text_field :title, class: "input" %>

<%= f.label :description %>
<%= f.text_area :description, class: "input" %>

<%= f.submit class: "btn btn-primary" %>
<% end %>

<%# Turbo form with custom response %>
<%= form_with model: @card, data: { turbo_stream: true } do |f| %>
...
<% end %>
```

## Stimulus Integration

```erb
<%# Controller attachment %>
<div data-controller="dropdown">
  <button data-action="click->dropdown#toggle">
    Options
  </button>
  <div data-dropdown-target="menu" class="hidden">
<%= render "card_menu", card: @card %>
  </div>
</div>
```

## Tailwind CSS

```erb
<%# Use utility classes %>
<div class="flex items-center gap-4 p-4 bg-white rounded-lg shadow">
<%= image_tag @user.avatar, class: "w-12 h-12 rounded-full" %>
  <div class="flex-1">
    <h3 class="font-semibold text-gray-900"><%= @user.name %></h3>
    <p class="text-sm text-gray-500"><%= @user.email %></p>
  </div>
</div>
```

## Colors (STRICT)

**RULE:** Use OKLCH for custom colors. Standard Tailwind utilities are allowed.

```erb
<%# ❌ BAD: Inline hex colors %>
<div class="bg-[#1a1d24]">

<%# ❌ BAD: RGB in styles %>
<div style="color: rgb(59, 130, 246);">

<%# ✅ GOOD: Theme colors (defined as OKLCH) %>
<div class="bg-dark-800">

<%# ✅ GOOD: Arbitrary OKLCH %>
<div class="bg-[oklch(15%_0.02_260)]">

<%# ✅ GOOD: Standard Tailwind utilities %>
<div class="text-red-500 bg-green-100">
```

## Helpers

```ruby
# app/helpers/cards_helper.rb
module CardsHelper
  def card_status_badge(card)
    status = card.closed? ? "closed" : "open"
    color = card.closed? ? "bg-gray-100 text-gray-600" : "bg-green-100 text-green-600"

    tag.span(status, class: "px-2 py-1 text-xs font-medium rounded #{color}")
  end
end
```

## Anti-patterns

```erb
<%# ❌ BAD: Logic in templates %>
<% cards = Card.where(board: @board).order(:created_at).limit(10) %>

<%# ✅ GOOD: Query in controller/model %>
<% @cards = @board.cards.recent %>

<%# ❌ BAD: Inline styles %>
<div style="color: red; font-size: 12px;">

<%# ✅ GOOD: Utility classes %>
<div class="text-red-500 text-sm">

<%# ❌ BAD: String concatenation for classes %>
<div class="card <%= 'card--closed' if @card.closed? %>">

<%# ✅ GOOD: class_names helper %>
<div class="<%= class_names('card', 'card--closed': @card.closed?) %>">

<%# ❌ BAD: Inline SVG code %>
<svg class="w-6 h-6">
  <path d="..." />
</svg>

<%# ✅ GOOD: inline_svg gem %>
<%= inline_svg "icons/users.svg", class: "w-6 h-6 text-blue-600" %>
```

## Icons with inline_svg

**STRICT RULE:** Never write inline SVG code directly in ERB files.

Always use the `inline_svg` gem:

```erb
<%= inline_svg "icons/users.svg", class: "w-6 h-6 text-blue-600" %>
<%= inline_svg "icons/chat.svg", class: "w-5 h-5 text-gray-400" %>
```

**Icon organization:**
- Store icons in `app/assets/images/icons/`
- Use semantic names: `users.svg`, `chat.svg`, `settings.svg`
- Keep SVG files clean (viewBox, paths only)
- Icons inherit color via `currentColor`
