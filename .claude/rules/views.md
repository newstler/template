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
```
