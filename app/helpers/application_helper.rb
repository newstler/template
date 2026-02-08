module ApplicationHelper
  # ── Open Graph helpers ──
  # Views set per-page values via content_for:
  #   content_for :og_title, @post.title
  #   content_for :og_description, @post.excerpt
  #   content_for :og_image, url_for(@post.og_image)
  #
  # Layout falls back to app-wide defaults from i18n.

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

  # ── Analytics ──

  def nullitics_enabled?
    Geocoder.config[:ip_lookup] == :geoip2
  end

  def country_code
    return @country_code if defined?(@country_code)

    @country_code = Rails.cache.fetch("geo:#{request.remote_ip}", expires_in: 1.year) do
      result = Geocoder.search(request.remote_ip).first
      result&.country_code&.upcase
    rescue => e
      Rails.logger.warn "Geocoder lookup failed: #{e.message}"
      nil
    end
  end

  # ── Markdown ──

  class MarkdownRenderer < Redcarpet::Render::HTML
    include Rouge::Plugins::Redcarpet

    def block_code(code, language)
      language ||= "text"
      formatter = Rouge::Formatters::HTMLLegacy.new(css_class: "highlight")
      lexer = Rouge::Lexer.find_fancy(language, code) || Rouge::Lexers::PlainText.new
      formatter.format(lexer.lex(code))
    end
  end

  def markdown(text)
    return "" if text.blank?

    options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank" },
      fenced_code_blocks: true,
      prettify: true,
      tables: true,
      with_toc_data: true,
      no_intra_emphasis: true
    }

    extensions = {
      autolink: true,
      superscript: true,
      disable_indented_code_blocks: true,
      fenced_code_blocks: true,
      tables: true,
      strikethrough: true,
      highlight: true
    }

    renderer = MarkdownRenderer.new(options)
    markdown_parser = Redcarpet::Markdown.new(renderer, extensions)

    markdown_parser.render(text).html_safe
  end
end
