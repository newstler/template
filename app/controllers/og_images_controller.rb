# frozen_string_literal: true

# Renders an HTML page at 1200x630 for screenshotting into a static OG image.
# Visit /og-image in a browser, resize to 1200x630, and screenshot.
# Save as public/og-image.png for use in meta tags.
class OgImagesController < ApplicationController
  layout false

  def show
    @app_name = t("app_name")
    @tagline = t("og_image.tagline")
    @domain = request.host
  end
end
