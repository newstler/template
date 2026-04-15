module ApplicationHelper
  include Chartkick::Helper

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
    Rails.configuration.x.nullitics
  end

  def country_code
    current_ip_country
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

  # ── Currency ──

  CURRENCY_SYMBOLS = {
    "USD" => "$", "EUR" => "€", "GBP" => "£", "CHF" => "CHF", "JPY" => "¥",
    "CNY" => "¥", "KRW" => "₩", "INR" => "₹", "RUB" => "₽", "UAH" => "₴",
    "TRY" => "₺", "PLN" => "zł", "SEK" => "kr", "NOK" => "kr", "DKK" => "kr",
    "CZK" => "Kč", "HUF" => "Ft", "RON" => "lei", "BRL" => "R$", "THB" => "฿",
    "ILS" => "₪", "PHP" => "₱", "MXN" => "$", "AUD" => "A$", "CAD" => "C$",
    "NZD" => "NZ$", "SGD" => "S$", "HKD" => "HK$", "ZAR" => "R"
  }.freeze

  def currency_symbol(code)
    CURRENCY_SYMBOLS.fetch(code.to_s.upcase, code.to_s.upcase)
  end

  def currency_name(code)
    I18n.t("currencies.#{code.to_s.upcase}", default: code.to_s.upcase)
  end

  def currency_options_for_select(selected = nil, include_auto: false, auto_label: nil)
    popular = CurrencyConvertible::POPULAR_CURRENCIES.map { |c| [ currency_name(c), c ] }
    rest = (CurrencyConvertible::SUPPORTED_CURRENCIES - CurrencyConvertible::POPULAR_CURRENCIES).sort.map { |c| [ currency_name(c), c ] }

    safe_join([
      (options_for_select([ [ auto_label || t("helpers.currency.auto"), "" ] ], selected.to_s) if include_auto),
      options_for_select(popular, selected.to_s),
      content_tag(:option, "───", disabled: true),
      options_for_select(rest, selected.to_s)
    ].compact)
  end

  def format_amount(value)
    return nil if value.nil?
    number_with_delimiter(value.to_i)
  end

  # ── Country ──

  def country_name(code)
    return nil if code.blank?
    country = ISO3166::Country.new(code)
    return code unless country
    country.translations[I18n.locale.to_s] || country.common_name
  end

  def country_flag(code)
    return "" if code.blank?
    ISO3166::Country.new(code)&.emoji_flag || ""
  end

  def country_options_for_select(selected = nil, include_blank: true, countries: nil)
    list = if countries
      countries.map { |c| ISO3166::Country.new(c) }.compact
    else
      ISO3166::Country.all
    end

    pairs = list.map do |country|
      name = country.translations[I18n.locale.to_s] || country.common_name
      [ "#{country.emoji_flag} #{name}", country.alpha2 ]
    end.sort_by { |pair| pair[0] }

    blank = include_blank ? tag.option("", value: "") : "".html_safe
    blank + options_for_select(pairs, selected)
  end

  # ── Markdown ──

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
