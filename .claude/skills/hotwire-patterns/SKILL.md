---
name: hotwire-patterns
description: Turbo and Stimulus patterns for Rails applications. Use when implementing interactivity, real-time updates, or frontend behavior without JavaScript frameworks.
trigger: turbo, stimulus, hotwire, frame, stream, javascript, frontend, spa
---

# Hotwire Patterns

## Philosophy

> "The HTML-over-the-wire approach. Turbo lets you get the speed of a single-page app without writing JavaScript."

**Core Principles:**
- Server renders HTML, not JSON
- Turbo handles navigation and updates
- Stimulus adds JS behavior when needed
- No build step, no npm

## Turbo Drive

Intercepts links and forms, fetches via AJAX, replaces `<body>`:

```erb
<%# Automatic - no code needed %>
<%= link_to "Dashboard", dashboard_path %>

<%# Disable for specific links %>
<%= link_to "External", "https://example.com", data: { turbo: false } %>

<%# Disable for a section %>
<div data-turbo="false">
  <%= link_to "Legacy", legacy_path %>
</div>
```

## Turbo Frames

Independent sections that update without full page reload:

```erb
<%# Define a frame %>
<%= turbo_frame_tag "card_#{@card.id}" do %>
  <%= render @card %>
<% end %>

<%# Navigation within frame stays in frame %>
<%= turbo_frame_tag "card_#{@card.id}" do %>
  <%= link_to "Edit", edit_card_path(@card) %>
<% end %>

<%# Break out of frame %>
<%= link_to "View Full", card_path(@card), data: { turbo_frame: "_top" } %>
```

### Lazy Loading

```erb
<%= turbo_frame_tag "comments",
      src: card_comments_path(@card),
      loading: :lazy do %>
  <p class="text-gray-500">Loading comments...</p>
<% end %>
```

### Frame Targeting

```erb
<%# Link targets different frame %>
<%= link_to "Preview", preview_card_path(@card),
      data: { turbo_frame: "preview" } %>

<%= turbo_frame_tag "preview" %>
```

## Turbo Streams

Real-time DOM updates:

### Actions

```erb
<%# Append to end of container %>
<%= turbo_stream.append "cards", @card %>

<%# Prepend to start %>
<%= turbo_stream.prepend "cards", @card %>

<%# Replace element %>
<%= turbo_stream.replace dom_id(@card), @card %>

<%# Update content (keep element) %>
<%= turbo_stream.update dom_id(@card), @card %>

<%# Remove element %>
<%= turbo_stream.remove dom_id(@card) %>

<%# Before/after specific element %>
<%= turbo_stream.before dom_id(@card), partial: "card", locals: { card: @new_card } %>
<%= turbo_stream.after dom_id(@card), partial: "card", locals: { card: @new_card } %>
```

### Controller Response

```ruby
class CardsController < ApplicationController
  def create
    @card = Current.user.cards.create!(card_params)

    respond_to do |format|
      format.html { redirect_to @card }
      format.turbo_stream  # renders create.turbo_stream.erb
    end
  end
end
```

```erb
<%# app/views/cards/create.turbo_stream.erb %>
<%= turbo_stream.prepend "cards", @card %>
<%= turbo_stream.update "card_count" do %>
  <%= Card.count %> cards
<% end %>
<%= turbo_stream.update "flash", partial: "shared/flash" %>
```

### Broadcasting (Real-time)

```ruby
# app/models/card.rb
class Card < ApplicationRecord
  after_create_commit -> { broadcast_prepend_to "cards" }
  after_update_commit -> { broadcast_replace_to "cards" }
  after_destroy_commit -> { broadcast_remove_to "cards" }
end
```

```erb
<%# Subscribe in view %>
<%= turbo_stream_from "cards" %>
<div id="cards">
  <%= render @cards %>
</div>
```

## Stimulus

### Basic Controller

```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static values = { open: Boolean }
  static classes = ["hidden"]

  connect() {
    this.openValue = false
  }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.menuTarget.classList.toggle(this.hiddenClass, !this.openValue)
  }

  // Close when clicking outside
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.openValue = false
    }
  }
}
```

```erb
<div data-controller="dropdown"
     data-dropdown-hidden-class="hidden"
     data-action="click@window->dropdown#clickOutside">
  <button data-action="click->dropdown#toggle">
    Menu
  </button>
  <div data-dropdown-target="menu" class="hidden">
    <%= render "menu_items" %>
  </div>
</div>
```

### Common Patterns

#### Form Submission

```javascript
// Auto-submit on change
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
```

```erb
<%= form_with model: @filter, data: { controller: "auto-submit" } do |f| %>
  <%= f.select :status, options, {}, data: { action: "change->auto-submit#submit" } %>
<% end %>
```

#### Clipboard

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value)
  }
}
```

#### Debounce

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 300)
  }
}
```

### Turbo Integration

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Runs when element connects
  }

  disconnect() {
    // Clean up before Turbo cache
  }

  // Handle Turbo events
  beforeCache() {
    this.element.innerHTML = ""  // Clear before caching
  }
}
```

## Best Practices

### DO

- Use Turbo Frames for isolated updates
- Use Turbo Streams for multi-element updates
- Keep Stimulus controllers small (<50 lines)
- Use data attributes for configuration
- Progressive enhancement (works without JS)

### DON'T

- Don't use npm/yarn packages
- Don't build SPAs with Stimulus
- Don't manipulate DOM directly (use Turbo)
- Don't store complex state in Stimulus
- Don't import React/Vue components
