---
description: Stimulus controller conventions
globs: ["app/javascript/controllers/**/*.js"]
---

# Stimulus Controller Standards

## Philosophy

- **JavaScript sprinkles, not applications** - Enhance HTML, don't replace it
- **Progressive enhancement** - Page works without JS
- **Data attributes for configuration** - No inline JS
- **One controller per concern** - Small, focused controllers

## Structure

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Declare targets first
  static targets = ["input", "output", "button"]

  // Then values
  static values = {
    url: String,
    refreshInterval: { type: Number, default: 5000 }
  }

  // Lifecycle callbacks
  connect() {
    // Called when controller connects to DOM
  }

  disconnect() {
    // Cleanup timers, subscriptions
  }

  // Action methods (verb names)
  toggle() {
    this.outputTarget.classList.toggle("hidden")
  }

  submit(event) {
    event.preventDefault()
    // Handle form submission
  }
}
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Controller file | `name_controller.js` | `dropdown_controller.js` |
| Controller identifier | kebab-case | `data-controller="dropdown"` |
| Actions | verbs | `toggle`, `submit`, `open`, `close` |
| Targets | nouns | `input`, `menu`, `button` |
| Values | descriptive | `url`, `refreshInterval` |

## HTML Usage

```erb
<%# Controller attachment %>
<div data-controller="dropdown">
  <%# Actions %>
  <button data-action="click->dropdown#toggle">Toggle</button>

  <%# Targets %>
  <div data-dropdown-target="menu" class="hidden">
    Menu content
  </div>
</div>

<%# Multiple controllers %>
<div data-controller="dropdown tooltip">
  ...
</div>

<%# Values %>
<div data-controller="refresh"
     data-refresh-url-value="<%= cards_path %>"
     data-refresh-interval-value="3000">
</div>
```

## Best Practices

1. **Keep controllers small** - Under 50 lines ideally
2. **No direct DOM queries** - Use targets
3. **No global state** - Use values for configuration
4. **Clean up in disconnect()** - Remove timers, event listeners
5. **Use Turbo first** - Only add Stimulus when Turbo isn't enough

## Anti-patterns

```javascript
// ❌ BAD: Direct DOM query
document.querySelector(".menu")

// ✅ GOOD: Use target
this.menuTarget

// ❌ BAD: Inline event handler
<button onclick="toggle()">

// ✅ GOOD: Data action
<button data-action="click->dropdown#toggle">

// ❌ BAD: Complex state management
this.state = { open: false, items: [] }

// ✅ GOOD: Use values or CSS classes
static values = { open: Boolean }
```

## Turbo Integration

```javascript
// Listen for Turbo events
connect() {
  document.addEventListener("turbo:before-cache", this.cleanup)
}

disconnect() {
  document.removeEventListener("turbo:before-cache", this.cleanup)
}

cleanup = () => {
  // Reset state before Turbo caches the page
}
```
