# frozen_string_literal: true

namespace :og_image do
  desc "Generate OG image by screenshotting /og-image route (requires Playwright)"
  task generate: :environment do
    require "open3"

    port = 3000
    url = "http://localhost:#{port}/og-image"
    output_path = Rails.root.join("public", "og-image.png")

    puts "Generating OG image from #{url}..."

    begin
      require "net/http"
      Net::HTTP.get_response(URI(url))
    rescue Errno::ECONNREFUSED
      puts "Error: Server not running on port #{port}. Start with: bin/dev"
      exit 1
    end

    script = <<~JS
      const { chromium } = require('playwright');
      (async () => {
        const browser = await chromium.launch();
        const page = await browser.newPage();
        await page.setViewportSize({ width: 1200, height: 630 });
        await page.goto('#{url}');
        await page.waitForLoadState('networkidle');
        await page.screenshot({ path: '#{output_path}' });
        await browser.close();
        console.log('Screenshot saved to #{output_path}');
      })();
    JS

    _, _, status = Open3.capture3("npx playwright --version")

    unless status.success?
      puts "Playwright not found. Run: npx playwright install"
      puts ""
      puts "Or generate manually — see: rake og_image:instructions"
      exit 1
    end

    stdout, stderr, status = Open3.capture3("node", "-e", script)

    if status.success?
      puts stdout
      puts "OG image saved to #{output_path}"
    else
      puts "Error: #{stderr}"
      exit 1
    end
  end

  desc "Show instructions for manual OG image generation"
  task instructions: :environment do
    puts <<~TEXT
      Manual OG Image Generation
      ==========================

      1. Start server:     bin/dev
      2. Open:             http://localhost:3000/og-image
      3. DevTools (F12) → device toolbar → 1200 x 630
      4. Right-click → "Capture screenshot"
      5. Save as:          public/og-image.png

      Per-page OG images
      ==================

      Any view can override the defaults:

        <% content_for :og_title, @post.title %>
        <% content_for :og_description, @post.excerpt %>
        <% content_for :og_image, "/og-images/posts/123.png" %>

      The layout automatically picks up these values.

      Verify
      ======

      Facebook:  https://developers.facebook.com/tools/debug/
      Twitter:   https://cards-dev.twitter.com/validator
      LinkedIn:  https://www.linkedin.com/post-inspector/

    TEXT
  end
end
