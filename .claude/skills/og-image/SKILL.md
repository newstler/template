---
name: og-image
description: Generate social media preview images (Open Graph) for Rails apps. Creates an OG image using the project's design system at /og-image, screenshots it at 1200x630, and configures meta tags in the layout head.
---

This skill creates Open Graph images for social media sharing in Rails apps. It generates a dedicated page at `/og-image` matching the project's design system, then screenshots it for use in meta tags.

## Architecture

The OG system has three layers:

1. **Helpers** in `ApplicationHelper` — `og_title`, `og_description`, `og_image`
2. **Meta tags** in `app/views/layouts/application.html.erb` — call the helpers
3. **Per-page overrides** — any view sets `content_for` to customize

```
Layout meta tags
  └─ og_title   → content_for(:og_title) → content_for(:title) → t("app_name")
  └─ og_description → content_for(:og_description) → t("og_image.description")
  └─ og_image   → content_for(:og_image) → request.base_url + "/og-image.png"
```

## Existing Files

These files already exist and should be edited, not recreated:

| File | Purpose |
|------|---------|
| `app/helpers/application_helper.rb` | `og_title`, `og_description`, `og_image` helpers |
| `app/views/layouts/application.html.erb` | OG + Twitter meta tags in `<head>` |
| `app/controllers/og_images_controller.rb` | Renders the screenshot page |
| `app/views/og_images/show.html.erb` | 1200x630 self-contained HTML page |
| `config/routes.rb` | `GET /og-image` route |
| `config/locales/en.yml` | `og_image.tagline` and `og_image.description` |
| `lib/tasks/og_image.rake` | `rake og_image:generate` and `rake og_image:instructions` |

## Workflow

### Phase 1: Understand the Design System

Read these files to match the project aesthetic:

- `app/assets/tailwind/application.css` — OKLCH color palette, fonts, custom utilities
- `app/views/layouts/application.html.erb` — existing meta tags and structure
- `app/assets/images/icons/` — available SVG icons for the image
- `config/locales/en.yml` — app name, tagline, description

### Phase 2: Update the OG Image Page

Edit `app/views/og_images/show.html.erb`. This is a self-contained page with `layout false`.

**Requirements:**
- Exactly 1200px wide × 630px tall
- Uses the project's Tailwind stylesheet
- All custom colors must use OKLCH (project rule)
- Uses `inline_svg` for icons (project rule — never inline SVG)
- No authentication required

**Template structure:**

```erb
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>OG Image</title>
  <%%= stylesheet_link_tag "tailwind" %>
  <style>
    html, body { margin: 0; padding: 0; width: 1200px; height: 630px; overflow: hidden; }
  </style>
</head>
<body>
  <div class="relative w-[1200px] h-[630px] ...">
    <%%= inline_svg "icons/lightning.svg", class: "w-14 h-14 text-white" %>
    <h1><%%= @app_name %></h1>
    <p><%%= @tagline %></p>
    <span><%%= @domain %></span>
  </div>
</body>
</html>
```

**Controller provides:**
- `@app_name` — from `t("app_name")`
- `@tagline` — from `t("og_image.tagline")`
- `@domain` — from `request.host`

### Phase 3: Screenshot

Tell the user to generate the static image:

```
1. Start server:     bin/dev
2. Open:             http://localhost:3000/og-image
3. DevTools (F12) → device toolbar → 1200 x 630
4. Right-click → "Capture screenshot"
5. Save as:          public/og-image.png
```

Or with Playwright: `rake og_image:generate`

### Phase 4: Per-Page OG Images

Any view can override defaults using `content_for`:

```erb
<%% content_for :og_title, @post.title %>
<%% content_for :og_description, @post.excerpt %>
<%% content_for :og_image, "/og-images/posts/#{@post.id}.png" %>
```

The helpers in `ApplicationHelper` cascade:

```ruby
def og_title
  content_for(:og_title).presence || content_for(:title).presence || t("app_name")
end

def og_description
  content_for(:og_description).presence || t("og_image.description")
end

def og_image
  if content_for?(:og_image)
    src = content_for(:og_image)
    src.start_with?("http") ? src : "#{request.base_url}#{src}"
  else
    "#{request.base_url}/og-image.png"
  end
end
```

### Phase 5: Verify

- [ ] `/og-image` renders at 1200×630
- [ ] `public/og-image.png` exists
- [ ] Meta tags render in page source (`og:image`, `twitter:image`)
- [ ] `og:image` URL is absolute (includes protocol + domain)
- [ ] Per-page overrides work via `content_for`
- [ ] `rails test` passes
- [ ] `bundle exec rubocop -A` passes

Social preview debuggers:
- Facebook: https://developers.facebook.com/tools/debug/
- Twitter: https://cards-dev.twitter.com/validator
- LinkedIn: https://www.linkedin.com/post-inspector/

## Key Rules

- **No env vars** — domain comes from `request.base_url` (configured via `bin/configure`)
- **No hardcoded strings** — app name and tagline come from i18n (`config/locales/en.yml`)
- **OKLCH colors only** — no hex/rgb/hsl in custom CSS
- **`inline_svg` for icons** — never paste raw SVG into templates
- **Minitest + fixtures** — for any new tests
