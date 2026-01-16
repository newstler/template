---
name: og-image
description: Generate social media preview images (Open Graph) for Rails apps. Creates an OG image using Ruby image libraries and configures meta tags in the layout head.
---

This skill creates Open Graph images for social media sharing in Rails applications. It generates an image file and adds the necessary meta tags to the layout.

## Workflow

### Phase 1: Codebase Analysis

Explore the project to understand:

1. **Design System Discovery (Tailwind 4)**
    - Check CSS config in `app/assets/stylesheets/application.css`:
      ```css
      @import "tailwindcss";
      
      @theme {
        --color-primary: oklch(0.7 0.15 250);
        --color-background: oklch(0.15 0.02 260);
        --font-display: "Inter", sans-serif;
      }
      ```
    - Find color tokens and fonts from `@theme` block

2. **Branding Assets**
    - Find logo in `app/assets/images/` or `public/`
    - Check for favicon in `public/`

3. **Product Information**
    - Extract product name from landing page
    - Find tagline/description

### Phase 2: Generate OG Image

Generate `public/og-image.png` (1200×630px) using one of these approaches:

**Option A: Using ruby-vips (already in Rails 7+)**

```ruby
# lib/tasks/og_image.rake
namespace :og do
  desc "Generate OG image"
  task generate: :environment do
    require "vips"
    
    width = 1200
    height = 630
    
    # Create background with gradient
    background = Vips::Image.black(width, height).add([30, 41, 59])  # slate-800
    
    # Add text
    title = Vips::Image.text(
      "Product Name",
      font: "Inter Bold 72",
      width: width - 200
    ).gravity("centre", width, 200)
    
    tagline = Vips::Image.text(
      "Your tagline here",
      font: "Inter 36",
      width: width - 200
    ).gravity("centre", width, 100)
    
    # Composite layers
    result = background
      .composite(title.add([255, 255, 255]), :over, x: 0, y: 200)
      .composite(tagline.add([148, 163, 184]), :over, x: 0, y: 350)
    
    result.write_to_file(Rails.root.join("public/og-image.png").to_s)
    puts "✓ Generated public/og-image.png"
  end
end
```

**Option B: Using MiniMagick**

```ruby
# Gemfile
gem "mini_magick"

# lib/tasks/og_image.rake
namespace :og do
  desc "Generate OG image"
  task generate: :environment do
    require "mini_magick"
    
    MiniMagick::Tool::Convert.new do |img|
      img.size "1200x630"
      img << "xc:#1e293b"  # slate-800 background
      img.gravity "center"
      img.font "Inter-Bold"
      img.pointsize 72
      img.fill "white"
      img.annotate "+0-50", "Product Name"
      img.font "Inter-Regular"
      img.pointsize 36
      img.fill "#94a3b8"  # slate-400
      img.annotate "+0+50", "Your tagline here"
      img << Rails.root.join("public/og-image.png").to_s
    end
    
    puts "✓ Generated public/og-image.png"
  end
end
```

**Option C: Playwright MCP (for complex designs)**

For complex designs, create temp HTML and screenshot:

```ruby
# lib/tasks/og_image.rake
namespace :og do
  desc "Generate OG image HTML for Playwright screenshot"
  task html: :environment do
    html_path = Rails.root.join("tmp/og-image.html")
    
    File.write(html_path, <<~HTML)
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            width: 1200px;
            height: 630px;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            font-family: system-ui, sans-serif;
          }
          h1 { color: white; font-size: 72px; font-weight: 700; }
          p { color: #94a3b8; font-size: 36px; margin-top: 24px; }
          .domain { position: absolute; bottom: 40px; color: #64748b; }
        </style>
      </head>
      <body>
        <h1>Product Name</h1>
        <p>Your tagline here</p>
        <div class="domain">yourproduct.com</div>
      </body>
      </html>
    HTML
    
    puts "Use Playwright MCP:"
    puts "  browser_navigate file://#{html_path}"
    puts "  browser_resize 1200x630"
    puts "  browser_screenshot → public/og-image.png"
  end
end
```

### Phase 3: Add Meta Tags to Layout

**Create helper** (`app/helpers/meta_tags_helper.rb`):

```ruby
module MetaTagsHelper
  def meta_tags(options = {})
    defaults = {
      title: "Product Name",
      description: "Your product description for social sharing",
      image: og_image_url,
      url: request.original_url,
      twitter_handle: nil
    }
    tags = defaults.merge(options)
    
    safe_join([
      tag.meta(name: "description", content: tags[:description]),
      tag.meta(name: "theme-color", content: "#1e293b"),
      
      # Open Graph
      tag.meta(property: "og:type", content: "website"),
      tag.meta(property: "og:title", content: tags[:title]),
      tag.meta(property: "og:description", content: tags[:description]),
      tag.meta(property: "og:url", content: tags[:url]),
      tag.meta(property: "og:image", content: tags[:image]),
      tag.meta(property: "og:image:width", content: "1200"),
      tag.meta(property: "og:image:height", content: "630"),
      
      # Twitter/X
      tag.meta(name: "twitter:card", content: "summary_large_image"),
      tag.meta(name: "twitter:title", content: tags[:title]),
      tag.meta(name: "twitter:description", content: tags[:description]),
      tag.meta(name: "twitter:image", content: tags[:image]),
      tags[:twitter_handle] ? tag.meta(name: "twitter:site", content: tags[:twitter_handle]) : nil
    ].compact, "\n")
  end
  
  private
  
  def og_image_url
    host = Rails.application.config.action_mailer.default_url_options&.dig(:host) || "localhost:3000"
    protocol = Rails.env.production? ? "https" : "http"
    "#{protocol}://#{host}/og-image.png"
  end
end
```

**Update layout** (`app/views/layouts/application.html.erb`):

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "Product Name" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= meta_tags(content_for(:meta_tags) || {}) %>
    
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

**Per-page custom meta** (optional):

```erb
<% content_for :meta_tags do %>
  <%= meta_tags(
    title: "Custom Page Title",
    description: "Custom description"
  ) %>
<% end %>
```

### Phase 4: Verification

```bash
# Generate image
bin/rails og:generate

# Verify
ls -la public/og-image.png

# Test validators
# - Facebook: https://developers.facebook.com/tools/debug/
# - Twitter: https://cards-dev.twitter.com/validator
# - LinkedIn: https://www.linkedin.com/post-inspector/
```

## Files Created

```
lib/tasks/og_image.rake         # Rake task to generate image
app/helpers/meta_tags_helper.rb # Meta tag helper  
public/og-image.png             # Generated image (1200×630)
```

## Quality Checklist

- [ ] Image is 1200×630 pixels
- [ ] Image saved to `public/og-image.png`
- [ ] `meta_tags` helper in layout `<head>`
- [ ] Production URL configured for absolute image path
- [ ] Tested with social media validators
